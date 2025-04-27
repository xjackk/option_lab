# frozen_string_literal: true

require 'numo/narray'

module OptionLab

  # Implementation of the Cox-Ross-Rubinstein (CRR) binomial tree model
  # for American and European options pricing
  module BinomialTree

    class << self

      # Price an option using the Cox-Ross-Rubinstein binomial tree model
      # @param option_type [String] 'call' or 'put'
      # @param s0 [Float] Spot price
      # @param x [Float] Strike price
      # @param r [Float] Risk-free interest rate
      # @param volatility [Float] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param n_steps [Integer] Number of time steps
      # @param is_american [Boolean] True for American options, false for European
      # @param dividend_yield [Float] Continuous dividend yield
      # @return [Float] Option price
      def price_option(option_type, s0, x, r, volatility, years_to_maturity, n_steps = 100, is_american = true, dividend_yield = 0.0)
        # Calculate time step
        dt = years_to_maturity / n_steps.to_f

        # Calculate up and down factors
        u = Math.exp(volatility * Math.sqrt(dt))
        d = 1.0 / u

        # Calculate risk-neutral probability
        effective_r = r - dividend_yield
        p = (Math.exp(effective_r * dt) - d) / (u - d)

        # Calculate discount factor
        discount = Math.exp(-r * dt)

        # Initialize price tree
        stock_prices = Array.new(n_steps + 1) { Array.new(n_steps + 1, 0.0) }
        option_values = Array.new(n_steps + 1) { Array.new(n_steps + 1, 0.0) }

        # Fill stock price tree
        (0..n_steps).each do |i|
          (0..i).each do |j|
            stock_prices[i][j] = s0 * (u**(i - j)) * (d**j)
          end
        end

        # Calculate option values at expiration (i = n_steps)
        (0..n_steps).each do |j|
          option_values[n_steps][j] = option_payoff(option_type, stock_prices[n_steps][j], x)
        end

        # Work backwards through the tree
        (n_steps - 1).downto(0) do |i|
          (0..i).each do |j|
            # Expected value (European option value)
            expected_value = discount * (p * option_values[i + 1][j] + (1 - p) * option_values[i + 1][j + 1])

            if is_american
              # For American options, compare with immediate exercise value
              exercise_value = option_payoff(option_type, stock_prices[i][j], x)
              option_values[i][j] = [expected_value, exercise_value].max
            else
              # For European options, use expected value
              option_values[i][j] = expected_value
            end
          end
        end

        # Root node contains the option price
        option_values[0][0]
      end

      # Calculate option payoff at expiration
      # @param option_type [String] 'call' or 'put'
      # @param stock_price [Float] Stock price
      # @param strike [Float] Strike price
      # @return [Float] Option payoff
      def option_payoff(option_type, stock_price, strike)
        if option_type == 'call'
          [stock_price - strike, 0.0].max
        elsif option_type == 'put'
          [strike - stock_price, 0.0].max
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end

      # Get a full binomial tree as a structured output
      # @param option_type [String] 'call' or 'put'
      # @param s0 [Float] Spot price
      # @param x [Float] Strike price
      # @param r [Float] Risk-free interest rate
      # @param volatility [Float] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param n_steps [Integer] Number of time steps
      # @param is_american [Boolean] True for American options, false for European
      # @param dividend_yield [Float] Continuous dividend yield
      # @return [Hash] Tree structure with stock prices and option values
      def get_tree(option_type, s0, x, r, volatility, years_to_maturity, n_steps = 15, is_american = true, dividend_yield = 0.0)
        # Calculate time step
        dt = years_to_maturity / n_steps.to_f

        # Calculate up and down factors
        u = Math.exp(volatility * Math.sqrt(dt))
        d = 1.0 / u

        # Calculate risk-neutral probability
        effective_r = r - dividend_yield
        p = (Math.exp(effective_r * dt) - d) / (u - d)

        # Calculate discount factor
        discount = Math.exp(-r * dt)

        # Initialize price tree
        stock_prices = Array.new(n_steps + 1) { Array.new(n_steps + 1, 0.0) }
        option_values = Array.new(n_steps + 1) { Array.new(n_steps + 1, 0.0) }
        exercise_flags = Array.new(n_steps + 1) { Array.new(n_steps + 1, false) }

        # Fill stock price tree
        (0..n_steps).each do |i|
          (0..i).each do |j|
            stock_prices[i][j] = s0 * (u**(i - j)) * (d**j)
          end
        end

        # Calculate option values at expiration (i = n_steps)
        (0..n_steps).each do |j|
          option_values[n_steps][j] = option_payoff(option_type, stock_prices[n_steps][j], x)
        end

        # Work backwards through the tree
        (n_steps - 1).downto(0) do |i|
          (0..i).each do |j|
            # Expected value (European option value)
            expected_value = discount * (p * option_values[i + 1][j] + (1 - p) * option_values[i + 1][j + 1])

            if is_american
              # For American options, compare with immediate exercise value
              exercise_value = option_payoff(option_type, stock_prices[i][j], x)

              if exercise_value > expected_value
                option_values[i][j] = exercise_value
                exercise_flags[i][j] = true
              else
                option_values[i][j] = expected_value
              end
            else
              # For European options, use expected value
              option_values[i][j] = expected_value
            end
          end
        end

        # Return tree structure
        {
          stock_prices: stock_prices,
          option_values: option_values,
          exercise_flags: exercise_flags,
          parameters: {
            option_type: option_type,
            spot_price: s0,
            strike_price: x,
            risk_free_rate: r,
            volatility: volatility,
            time_to_maturity: years_to_maturity,
            steps: n_steps,
            is_american: is_american,
            dividend_yield: dividend_yield,
            up_factor: u,
            down_factor: d,
            risk_neutral_probability: p,
          },
        }
      end

      # Calculate option Greeks using the CRR model and finite difference methods
      # @param option_type [String] 'call' or 'put'
      # @param s0 [Float] Spot price
      # @param x [Float] Strike price
      # @param r [Float] Risk-free interest rate
      # @param volatility [Float] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param n_steps [Integer] Number of time steps
      # @param is_american [Boolean] True for American options, false for European
      # @param dividend_yield [Float] Continuous dividend yield
      # @return [Hash] Option Greeks (delta, gamma, theta, vega, rho)
      def get_greeks(option_type, s0, x, r, volatility, years_to_maturity, n_steps = 100, is_american = true, dividend_yield = 0.0)
        # Small increment for finite difference calculation
        h_s = s0 * 0.001    # For Delta and Gamma
        h_t = 1.0 / 365     # For Theta (1 day)
        h_v = 0.001         # For Vega
        h_r = 0.0001        # For Rho

        # Base price
        price = price_option(option_type, s0, x, r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)

        # Delta: ∂V/∂S
        price_up = price_option(option_type, s0 + h_s, x, r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)
        price_down = price_option(option_type, s0 - h_s, x, r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)
        delta = (price_up - price_down) / (2 * h_s)

        # Gamma: ∂²V/∂S²
        gamma = (price_up - 2 * price + price_down) / (h_s * h_s)

        # Theta: -∂V/∂t
        price_t_down = if years_to_maturity - h_t > 0
          price_option(option_type, s0, x, r, volatility, years_to_maturity - h_t, n_steps, is_american, dividend_yield)
        else
          option_payoff(option_type, s0, x)
        end
        theta = -(price_t_down - price) / h_t

        # Vega: ∂V/∂σ
        price_v_up = price_option(option_type, s0, x, r, volatility + h_v, years_to_maturity, n_steps, is_american, dividend_yield)
        vega = (price_v_up - price) / h_v

        # Rho: ∂V/∂r
        price_r_up = price_option(option_type, s0, x, r + h_r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)
        rho = (price_r_up - price) / h_r

        # Return Greeks
        {
          delta: delta,
          gamma: gamma,
          theta: theta,
          vega: vega,
          rho: rho,
        }
      end

    end

  end

end
