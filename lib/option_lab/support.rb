# frozen_string_literal: true

require 'numo/narray'
require 'distribution'

module OptionLab
  module Support
    # Cache for create_price_seq method
    @price_seq_cache = {}
    
    class << self
      # Get profit/loss profile and cost of an options trade at expiration
      # @param option_type [String] 'call' or 'put'
      # @param action [String] 'buy' or 'sell'
      # @param x [Float] Strike price
      # @param val [Float] Option price
      # @param n [Integer] Number of options
      # @param s [Numo::DFloat] Array of stock prices
      # @param commission [Float] Brokerage commission
      # @return [Array<Numo::DFloat, Float>] P/L profile and cost
      def get_pl_profile(option_type, action, x, val, n, s, commission = 0.0)
        if action == 'buy'
          cost = -val
        elsif action == 'sell'
          cost = val
        else
          raise ArgumentError, "Action must be either 'buy' or 'sell'!"
        end
        
        if Models::OPTION_TYPES.include?(option_type)
          [
            n * _get_pl_option(option_type, val, action, s, x) - commission,
            n * cost - commission
          ]
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end
    
      # Get profit/loss profile and cost of a stock position
      # @param s0 [Float] Initial stock price
      # @param action [String] 'buy' or 'sell'
      # @param n [Integer] Number of shares
      # @param s [Numo::DFloat] Array of stock prices
      # @param commission [Float] Brokerage commission
      # @return [Array<Numo::DFloat, Float>] P/L profile and cost
      def get_pl_profile_stock(s0, action, n, s, commission = 0.0)
        if action == 'buy'
          cost = -s0
        elsif action == 'sell'
          cost = s0
        else
          raise ArgumentError, "Action must be either 'buy' or 'sell'!"
        end
        
        [
          n * _get_pl_stock(s0, action, s) - commission,
          n * cost - commission
        ]
      end
    
      # Get profit/loss profile and cost of an options trade before expiration using Black-Scholes
      # @param option_type [String] 'call' or 'put'
      # @param action [String] 'buy' or 'sell'
      # @param x [Float] Strike price
      # @param val [Float] Option price
      # @param r [Float] Risk-free interest rate
      # @param target_to_maturity_years [Float] Time remaining to maturity from target date
      # @param volatility [Float] Volatility
      # @param n [Integer] Number of options
      # @param s [Numo::DFloat] Array of stock prices
      # @param y [Float] Dividend yield
      # @param commission [Float] Brokerage commission
      # @return [Array<Numo::DFloat, Float>] P/L profile and cost
      def get_pl_profile_bs(option_type, action, x, val, r, target_to_maturity_years, volatility, n, s, y = 0.0, commission = 0.0)
        if action == 'buy'
          cost = -val
          factor = 1
        elsif action == 'sell'
          cost = val
          factor = -1
        else
          raise ArgumentError, "Action must be either 'buy' or 'sell'!"
        end
        
        # Calculate prices using Black-Scholes
        d1 = BlackScholes.get_d1(s, x, r, volatility, target_to_maturity_years, y)
        d2 = BlackScholes.get_d2(s, x, r, volatility, target_to_maturity_years, y)
        calc_price = BlackScholes.get_option_price(option_type, s, x, r, target_to_maturity_years, d1, d2, y)
        
        profile = factor * n * (calc_price - val) - commission
        
        [profile, n * cost - commission]
      end
    
      # Generate a sequence of stock prices from min to max with $0.01 increment
      # @param min_price [Float] Minimum stock price
      # @param max_price [Float] Maximum stock price
      # @return [Numo::DFloat] Array of sequential stock prices
      def create_price_seq(min_price, max_price)
        cache_key = "#{min_price}-#{max_price}"
        
        # Return cached result if available
        return @price_seq_cache[cache_key] if @price_seq_cache.key?(cache_key)
        
        if max_price > min_price
          # Create array with increment 0.01
          steps = ((max_price - min_price) * 100 + 1).to_i
          arr = Numo::DFloat.new(steps).seq(min_price, 0.01)
          
          # Round to 2 decimal places (Numo::DFloat doesn't support arguments to round)
          arr = arr.round
          
          # Cache the result
          @price_seq_cache[cache_key] = arr
          
          arr
        else
          raise ArgumentError, "Maximum price cannot be less than minimum price!"
        end
      end
    
      # Estimate probability of profit
      # @param s [Numo::DFloat] Array of stock prices
      # @param profit [Numo::DFloat] Array of profits
      # @param inputs_data [Models::BlackScholesModelInputs, Models::ArrayInputs] Model inputs
      # @param target [Float] Return target
      # @return [Models::PoPOutputs] Probability of profit outputs
      def get_pop(s, profit, inputs_data, target = 0.01)
        # Initialize variables
        probability_of_reaching_target = 0.0
        probability_of_missing_target = 0.0
        expected_return_above_target = nil
        expected_return_below_target = nil
        
        # Get profit ranges
        t_ranges = _get_profit_range(s, profit, target)
        
        reaching_target_range = t_ranges[0] == [[0.0, 0.0]] ? [] : t_ranges[0]
        missing_target_range = t_ranges[1] == [[0.0, 0.0]] ? [] : t_ranges[1]
        
        # Calculate PoP based on inputs model
        if inputs_data.is_a?(Models::BlackScholesModelInputs)
          probability_of_reaching_target, expected_return_above_target,
          probability_of_missing_target, expected_return_below_target = 
            _get_pop_bs(s, profit, inputs_data, t_ranges)
        elsif inputs_data.is_a?(Models::ArrayInputs)
          probability_of_reaching_target, expected_return_above_target,
          probability_of_missing_target, expected_return_below_target = 
            _get_pop_array(inputs_data, target)
        end
        
        # Return outputs
        Models::PoPOutputs.new(
          probability_of_reaching_target: probability_of_reaching_target,
          probability_of_missing_target: probability_of_missing_target,
          reaching_target_range: reaching_target_range,
          missing_target_range: missing_target_range,
          expected_return_above_target: expected_return_above_target,
          expected_return_below_target: expected_return_below_target
        )
      end
    
      # Create price array for simulations
      # @param inputs_data [Hash, Models::BlackScholesModelInputs, Models::LaplaceInputs] Model inputs
      # @param n [Integer] Number of prices to generate
      # @param seed [Integer, nil] Random seed
      # @return [Numo::DFloat] Array of prices
      def create_price_array(inputs_data, n: 100_000, seed: nil)
        # Set random seed if provided
        Kernel.srand(seed) if seed
        
        # Convert hash to appropriate model if needed
        inputs = if inputs_data.is_a?(Hash)
                  if %w[black-scholes normal].include?(inputs_data[:model] || inputs_data['model'])
                    Models::BlackScholesModelInputs.new(inputs_data)
                  elsif (inputs_data[:model] || inputs_data['model']) == 'laplace'
                    Models::LaplaceInputs.new(inputs_data)
                  else
                    raise ArgumentError, "Invalid model type!"
                  end
                else
                  inputs_data
                end
        
        # Generate array based on model
        arr = if inputs.is_a?(Models::BlackScholesModelInputs)
                _get_array_price_from_BS(inputs, n)
              elsif inputs.is_a?(Models::LaplaceInputs)
                _get_array_price_from_laplace(inputs, n)
              else
                raise ArgumentError, "Invalid inputs type!"
              end
        
        # Reset random seed
        Kernel.srand if seed
        
        arr
      end
    
      private
      
      # Calculate P/L of an option at expiration
      # @param option_type [String] 'call' or 'put'
      # @param opvalue [Float] Option price
      # @param action [String] 'buy' or 'sell'
      # @param s [Numo::DFloat] Array of stock prices
      # @param x [Float] Strike price
      # @return [Numo::DFloat] P/L profile
      def _get_pl_option(option_type, opvalue, action, s, x)
        if action == 'sell'
          opvalue - _get_payoff(option_type, s, x)
        elsif action == 'buy'
          _get_payoff(option_type, s, x) - opvalue
        else
          raise ArgumentError, "Action must be either 'sell' or 'buy'!"
        end
      end
    
      # Calculate option payoff at expiration
      # @param option_type [String] 'call' or 'put'
      # @param s [Numo::DFloat] Array of stock prices
      # @param x [Float] Strike price
      # @return [Numo::DFloat] Option payoff
      def _get_payoff(option_type, s, x)
        if option_type == 'call'
          diff = s - x
          (diff + diff.abs) / 2.0
        elsif option_type == 'put'
          diff = x - s
          (diff + diff.abs) / 2.0
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end
    
      # Calculate P/L of a stock position
      # @param s0 [Float] Spot price
      # @param action [String] 'buy' or 'sell'
      # @param s [Numo::DFloat] Array of stock prices
      # @return [Numo::DFloat] P/L profile
      def _get_pl_stock(s0, action, s)
        if action == 'sell'
          s0 - s
        elsif action == 'buy'
          s - s0
        else
          raise ArgumentError, "Action must be either 'sell' or 'buy'!"
        end
      end
    
      # Calculate PoP using Black-Scholes model
      # @param s [Numo::DFloat] Array of stock prices
      # @param profit [Numo::DFloat] Array of profits
      # @param inputs [Models::BlackScholesModelInputs] Model inputs
      # @param profit_range [Array<Array<Array<Float>>>] Profit and loss ranges
      # @return [Array<Float, Float, Float, Float>] PoP calculation results
      def _get_pop_bs(s, profit, inputs, profit_range)
        # Initialize variables
        expected_return_above_target = nil
        expected_return_below_target = nil
        probability_of_reaching_target = 0.0
        probability_of_missing_target = 0.0
        
        # Calculate sigma
        sigma = inputs.volatility > 0.0 ? 
          inputs.volatility * Math.sqrt(inputs.years_to_target_date) : 1e-10
        
        # Calculate PoP for each range
        profit_range.each_with_index do |t, i|
          prob = 0.0
          
          if t != [[0.0, 0.0]]
            t.each do |p_range|
              # Calculate log values
              lval = p_range[0] > 0.0 ? Math.log(p_range[0]) : -Float::INFINITY
              hval = Math.log(p_range[1])
              
              # Calculate drift and mean
              drift = (
                inputs.interest_rate - 
                inputs.dividend_yield - 
                0.5 * inputs.volatility * inputs.volatility
              ) * inputs.years_to_target_date
              
              m = Math.log(inputs.stock_price) + drift
              
              # Calculate probability
              prob += Distribution::Normal.cdf((hval - m) / sigma) - Distribution::Normal.cdf((lval - m) / sigma)
            end
          end
          
          if i == 0
            probability_of_reaching_target = prob
          else
            probability_of_missing_target = prob
          end
        end
        
        [
          probability_of_reaching_target,
          expected_return_above_target,
          probability_of_missing_target,
          expected_return_below_target
        ]
      end
    
      # Calculate PoP using array of terminal prices
      # @param inputs [Models::ArrayInputs] Array inputs
      # @param target [Float] Return target
      # @return [Array<Float, Float, Float, Float>] PoP calculation results
      def _get_pop_array(inputs, target)
        if inputs.array.size == 0
          raise ArgumentError, "The array is empty!"
        end
        
        # Split array by target
        above_target = inputs.array[inputs.array >= target]
        below_target = inputs.array[inputs.array < target]
        
        # Calculate probabilities
        probability_of_reaching_target = above_target.size.to_f / inputs.array.size
        probability_of_missing_target = 1.0 - probability_of_reaching_target
        
        # Calculate expected returns
        expected_return_above_target = above_target.size > 0 ? above_target.mean.round(2) : nil
        expected_return_below_target = below_target.size > 0 ? below_target.mean.round(2) : nil
        
        [
          probability_of_reaching_target,
          expected_return_above_target,
          probability_of_missing_target,
          expected_return_below_target
        ]
      end
    
      # Find profit/loss ranges
      # @param s [Numo::DFloat] Array of stock prices
      # @param profit [Numo::DFloat] Array of profits
      # @param target [Float] Profit target
      # @return [Array<Array<Array<Float>>>] Profit and loss ranges
      def _get_profit_range(s, profit, target = 0.01)
        profit_range = []
        loss_range = []
        
        # Find where profit crosses target
        crossings = _get_sign_changes(profit, target)
        n_crossings = crossings.size
        
        # Handle case with no crossings
        if n_crossings == 0
          if profit[0] >= target
            return [[[0.0, Float::INFINITY]], [[0.0, 0.0]]]
          else
            return [[[0.0, 0.0]], [[0.0, Float::INFINITY]]]
          end
        end
        
        # Find profit and loss ranges
        lb_profit = hb_profit = nil
        lb_loss = hb_loss = nil
        
        crossings.each_with_index do |index, i|
          if i == 0
            if profit[index] < profit[index - 1]
              lb_profit = 0.0
              hb_profit = s[index - 1]
              lb_loss = s[index]
              
              hb_loss = Float::INFINITY if n_crossings == 1
            else
              lb_profit = s[index]
              lb_loss = 0.0
              hb_loss = s[index - 1]
              
              hb_profit = Float::INFINITY if n_crossings == 1
            end
          elsif i == n_crossings - 1
            if profit[index] > profit[index - 1]
              lb_profit = s[index]
              hb_profit = Float::INFINITY
              hb_loss = s[index - 1]
            else
              hb_profit = s[index - 1]
              lb_loss = s[index]
              hb_loss = Float::INFINITY
            end
          else
            if profit[index] > profit[index - 1]
              lb_profit = s[index]
              hb_loss = s[index - 1]
            else
              hb_profit = s[index - 1]
              lb_loss = s[index]
            end
          end
          
          if lb_profit && hb_profit
            profit_range << [lb_profit, hb_profit]
            lb_profit = hb_profit = nil
          end
          
          if lb_loss && hb_loss
            loss_range << [lb_loss, hb_loss]
            lb_loss = hb_loss = nil
          end
        end
        
        [profit_range, loss_range]
      end
    
      # Find indices where profit crosses target
      # @param profit [Numo::DFloat] Array of profits
      # @param target [Float] Profit target
      # @return [Array<Integer>] Array of indices
      def _get_sign_changes(profit, target)
        # Subtract target and add small epsilon
        p_temp = profit - target + 1e-10
        
        # Get signs (convert to array first since Numo::DFloat doesn't have collect)
        signs_1 = p_temp[0...-1].to_a.map { |v| v > 0 ? 1 : -1 }
        signs_2 = p_temp[1..-1].to_a.map { |v| v > 0 ? 1 : -1 }
        
        # Find sign changes
        changes = []
        signs_1.each_with_index do |s1, i|
          changes << i + 1 if s1 * signs_2[i] < 0
        end
        
        changes
      end
    
      # Generate array of prices using Black-Scholes model
      # @param inputs [Models::BlackScholesModelInputs] Black-Scholes inputs
      # @param n [Integer] Number of prices to generate
      # @return [Numo::DFloat] Array of prices
      def _get_array_price_from_BS(inputs, n)
        # Calculate mean and std
        mean = Math.log(inputs.stock_price) + 
               (inputs.interest_rate - inputs.dividend_yield - 0.5 * inputs.volatility**2) * 
               inputs.years_to_target_date
        std = inputs.volatility * Math.sqrt(inputs.years_to_target_date)
        
        # Generate random values
        random_values = Numo::DFloat.new(n).rand_norm(0, 1)
        
        # Apply formula
        Numo::NMath.exp(mean + std * random_values)
      end
    
      # Generate array of prices using Laplace distribution
      # @param inputs [Models::LaplaceInputs] Laplace inputs
      # @param n [Integer] Number of prices to generate
      # @return [Numo::DFloat] Array of prices
      def _get_array_price_from_laplace(inputs, n)
        # Calculate location and scale
        location = Math.log(inputs.stock_price) + inputs.mu * inputs.years_to_target_date
        scale = (inputs.volatility * Math.sqrt(inputs.years_to_target_date)) / Math.sqrt(2.0)
        
        # Generate random values from uniform distribution
        u = Numo::DFloat.new(n).rand - 0.5
        
        # Convert to Laplace distribution
        laplace_values = location - scale * u.abs.map { |v| v < 0 ? -1 : 1 } * Numo::NMath.log(1 - 2 * u.abs)
        
        # Apply formula
        Numo::NMath.exp(laplace_values)
      end
    end
  end
end