# frozen_string_literal: true

require 'date'
require 'numo/narray'

module OptionLab

  module Engine
    class << self
      # Run strategy calculation
      # @param inputs_data [Hash, Models::Inputs] Input data for strategy calculation
      # @return [Models::Outputs] Output data from strategy calculation
      def run_strategy(inputs_data)
        # Convert hash to Inputs if needed
        inputs = if inputs_data.is_a?(Models::Inputs)
          inputs_data
        else
          Models::Inputs.new(inputs_data)
        end

        # Initialize data
        data = _init_inputs(inputs)

        # Run calculations
        data = _run(data)

        # Generate outputs
        _generate_outputs(data)
      end

      # Initialize input data
      # @param inputs [Models::Inputs] Input data
      # @return [Models::EngineData] Initialized engine data
      def _init_inputs(inputs)
      # Create engine data
      data = Models::EngineData.new(
        stock_price_array: Support.create_price_seq(inputs.min_stock, inputs.max_stock),
        terminal_stock_prices: inputs.model == 'array' ? inputs.array : Models.init_empty_array,
        inputs: inputs,
      )

      # Set days in year
      data.days_in_year = inputs.discard_nonbusiness_days ? inputs.business_days_in_year : 365

      # Calculate days to target
      if inputs.start_date && inputs.target_date
        n_discarded_days = if inputs.discard_nonbusiness_days
          Utils.get_nonbusiness_days(
            inputs.start_date, inputs.target_date, inputs.country
          )
        else
          0
        end

        data.days_to_target = (inputs.target_date - inputs.start_date).to_i + 1 - n_discarded_days
      else
        data.days_to_target = inputs.days_to_target_date
      end

      # Process each strategy leg
      inputs.strategy.each_with_index do |strategy, _i|
        data.type << strategy.type

        case strategy
        when Models::Option
          data.strike << strategy.strike
          data.premium << strategy.premium
          data.n << strategy.n
          data.action << strategy.action
          data.previous_position << strategy.prev_pos || 0.0

          if !strategy.expiration
            data.days_to_maturity << data.days_to_target
            data.use_bs << false
          elsif strategy.expiration.is_a?(Date) && inputs.start_date
            n_discarded_days = if inputs.discard_nonbusiness_days
              Utils.get_nonbusiness_days(
                inputs.start_date, strategy.expiration, inputs.country
              )
            else
              0
            end

            data.days_to_maturity << (strategy.expiration - inputs.start_date).to_i + 1 - n_discarded_days
            data.use_bs << (strategy.expiration != inputs.target_date)
          elsif strategy.expiration.is_a?(Integer)
            if strategy.expiration >= data.days_to_target
              data.days_to_maturity << strategy.expiration
              data.use_bs << (strategy.expiration != data.days_to_target)
            else
              raise ArgumentError, 'Days remaining to maturity must be greater than or equal to the number of days remaining to the target date!'
            end
          else
            raise ArgumentError, 'Expiration must be a date, an int, or nil.'
          end

        when Models::Stock
          data.n << strategy.n
          data.action << strategy.action
          data.previous_position << strategy.prev_pos || 0.0
          data.strike << 0.0
          data.premium << 0.0
          data.use_bs << false
          data.days_to_maturity << -1

        when Models::ClosedPosition
          data.previous_position << strategy.prev_pos
          data.strike << 0.0
          data.n << 0
          data.premium << 0.0
          data.action << 'n/a'
          data.use_bs << false
          data.days_to_maturity << -1

        else
          raise ArgumentError, "Type must be 'call', 'put', 'stock' or 'closed'!"
        end
      end

      data
    end

      # Run calculations
      # @param data [Models::EngineData] Engine data
      # @return [Models::EngineData] Updated engine data
      def _run(data)
      inputs = data.inputs

      # Calculate time to target
      time_to_target = data.days_to_target.to_f / data.days_in_year

      # Initialize arrays
      data.cost = Array.new(data.type.size, 0.0)
      data.profit = Numo::DFloat.zeros(data.type.size, data.stock_price_array.size)
      data.strategy_profit = Numo::DFloat.zeros(data.stock_price_array.size)

      if inputs.model == 'array'
        data.profit_mc = Numo::DFloat.zeros(data.type.size, data.terminal_stock_prices.size)
        data.strategy_profit_mc = Numo::DFloat.zeros(data.terminal_stock_prices.size)
      end

      # Process each strategy leg
      data.type.each_with_index do |type, i|
        case type
        when 'call', 'put'
          _run_option_calcs(data, i)
        when 'stock'
          _run_stock_calcs(data, i)
        when 'closed'
          _run_closed_position_calcs(data, i)
        end

        # Add to strategy profit
        data.strategy_profit += data.profit[i, true]

        if inputs.model == 'array'
          data.strategy_profit_mc += data.profit_mc[i, true]
        end
      end

      # Calculate probability of profit
      pop_inputs = if inputs.model == 'array'
        Models::ArrayInputs.new(
          array: data.strategy_profit_mc,
        )
      else
        Models::BlackScholesModelInputs.new(
          stock_price: inputs.stock_price,
          volatility: inputs.volatility,
          years_to_target_date: time_to_target,
          interest_rate: inputs.interest_rate,
          dividend_yield: inputs.dividend_yield,
        )
      end

      pop_out = Support.get_pop(data.stock_price_array, data.strategy_profit, pop_inputs)

      # Store results
      data.profit_probability = pop_out.probability_of_reaching_target
      data.expected_profit = pop_out.expected_return_above_target
      data.expected_loss = pop_out.expected_return_below_target
      data.profit_ranges = pop_out.reaching_target_range

      # Calculate profit target probability if needed
      if inputs.profit_target && inputs.profit_target > 0.01
        pop_out_prof_targ = Support.get_pop(
          data.stock_price_array,
          data.strategy_profit,
          pop_inputs,
          inputs.profit_target,
        )

        data.profit_target_probability = pop_out_prof_targ.probability_of_reaching_target
        data.profit_target_ranges = pop_out_prof_targ.reaching_target_range
      end

      # Calculate loss limit probability if needed
      if inputs.loss_limit && inputs.loss_limit < 0.0
        pop_out_loss_lim = Support.get_pop(
          data.stock_price_array,
          data.strategy_profit,
          pop_inputs,
          inputs.loss_limit + 0.01,
        )

        data.loss_limit_probability = pop_out_loss_lim.probability_of_missing_target
        data.loss_limit_ranges = pop_out_loss_lim.missing_target_range
      end

      data
    end

      # Run option calculations
      # @param data [Models::EngineData] Engine data
      # @param i [Integer] Index of strategy leg
      # @return [Models::EngineData] Updated engine data
      def _run_option_calcs(data, i)
      inputs = data.inputs
      action = data.action[i]
      type = data.type[i]

      if data.previous_position[i] && data.previous_position[i] < 0.0
        # Previous position is closed
        data.implied_volatility << 0.0
        data.itm_probability << 0.0
        data.delta << 0.0
        data.gamma << 0.0
        data.vega << 0.0
        data.theta << 0.0
        data.rho << 0.0

        cost = (data.premium[i] + data.previous_position[i]) * data.n[i]
        cost *= -1.0 if data.action[i] == 'buy'

        data.cost[i] = cost
        data.profit[i, true] += cost

        if inputs.model == 'array'
          data.profit_mc[i, true] += cost
        end

        return data
      end

      # Calculate option metrics
      time_to_maturity = data.days_to_maturity[i].to_f / data.days_in_year

      bs = BlackScholes.get_bs_info(
        inputs.stock_price,
        data.strike[i],
        inputs.interest_rate,
        inputs.volatility,
        time_to_maturity,
        inputs.dividend_yield,
      )

      # Store Greeks
      data.gamma << bs.gamma
      data.vega << bs.vega

      data.implied_volatility << BlackScholes.get_implied_vol(
        type,
        data.premium[i],
        inputs.stock_price,
        data.strike[i],
        inputs.interest_rate,
        time_to_maturity,
        inputs.dividend_yield,
      )

      # Set multiplier for buy/sell
      negative_multiplier = data.action[i] == 'buy' ? 1 : -1

      # Store type-specific metrics
      if type == 'call'
        data.itm_probability << bs.call_itm_prob
        data.delta << bs.call_delta * negative_multiplier
        data.theta << bs.call_theta / data.days_in_year * negative_multiplier
        data.rho << bs.call_rho * negative_multiplier
      else
        data.itm_probability << bs.put_itm_prob
        data.delta << bs.put_delta * negative_multiplier
        data.theta << bs.put_theta / data.days_in_year * negative_multiplier
        data.rho << bs.put_rho * negative_multiplier
      end

      # Use previous position premium if available
      opt_value = (data.previous_position[i] && data.previous_position[i] > 0.0) ? data.previous_position[i] : data.premium[i]

      # Calculate profit/loss profile
      if data.use_bs[i]
        target_to_maturity = (data.days_to_maturity[i] - data.days_to_target).to_f / data.days_in_year

        profit, cost = Support.get_pl_profile_bs(
          type,
          action,
          data.strike[i],
          opt_value,
          inputs.interest_rate,
          target_to_maturity,
          inputs.volatility,
          data.n[i],
          data.stock_price_array,
          inputs.dividend_yield,
          inputs.opt_commission,
        )

        data.profit[i, true] = profit
        data.cost[i] = cost

        if inputs.model == 'array'
          data.profit_mc[i, true] = Support.get_pl_profile_bs(
            type,
            action,
            data.strike[i],
            opt_value,
            inputs.interest_rate,
            target_to_maturity,
            inputs.volatility,
            data.n[i],
            data.terminal_stock_prices,
            inputs.dividend_yield,
            inputs.opt_commission,
          )[0]
        end
      else
        profit, cost = Support.get_pl_profile(
          type,
          action,
          data.strike[i],
          opt_value,
          data.n[i],
          data.stock_price_array,
          inputs.opt_commission,
        )

        data.profit[i, true] = profit
        data.cost[i] = cost

        if inputs.model == 'array'
          data.profit_mc[i, true] = Support.get_pl_profile(
            type,
            action,
            data.strike[i],
            opt_value,
            data.n[i],
            data.terminal_stock_prices,
            inputs.opt_commission,
          )[0]
        end
      end

      data
    end

      # Run stock calculations
      # @param data [Models::EngineData] Engine data
      # @param i [Integer] Index of strategy leg
      # @return [Models::EngineData] Updated engine data
      def _run_stock_calcs(data, i)
      inputs = data.inputs
      action = data.action[i]

      # Set delta based on action
      data.delta << (action == 'buy' ? 1.0 : -1.0)

      # Set other metrics
      data.itm_probability << 1.0
      data.implied_volatility << 0.0
      data.gamma << 0.0
      data.vega << 0.0
      data.rho << 0.0
      data.theta << 0.0

      if data.previous_position[i] && data.previous_position[i] < 0.0
        # Previous position is closed
        costtmp = (inputs.stock_price + data.previous_position[i]) * data.n[i]
        costtmp *= -1.0 if data.action[i] == 'buy'

        data.cost[i] = costtmp
        data.profit[i, true] += costtmp

        if inputs.model == 'array'
          data.profit_mc[i, true] += costtmp
        end

        return data
      end

      # Use previous position if available
      stockpos = (data.previous_position[i] && data.previous_position[i] > 0.0) ? data.previous_position[i] : inputs.stock_price

      # Calculate profit/loss profile
      profit, cost = Support.get_pl_profile_stock(
        stockpos,
        action,
        data.n[i],
        data.stock_price_array,
        inputs.stock_commission,
      )

      data.profit[i, true] = profit
      data.cost[i] = cost

      if inputs.model == 'array'
        data.profit_mc[i, true] = Support.get_pl_profile_stock(
          stockpos,
          action,
          data.n[i],
          data.terminal_stock_prices,
          inputs.stock_commission,
        )[0]
      end

      data
    end

      # Run closed position calculations
      # @param data [Models::EngineData] Engine data
      # @param i [Integer] Index of strategy leg
      # @return [Models::EngineData] Updated engine data
      def _run_closed_position_calcs(data, i)
      # Set metrics
      data.implied_volatility << 0.0
      data.itm_probability << 0.0
      data.delta << 0.0
      data.gamma << 0.0
      data.vega << 0.0
      data.rho << 0.0
      data.theta << 0.0

      # Set cost and profit
      data.cost[i] = data.previous_position[i]
      data.profit[i, true] += data.previous_position[i]

      if data.inputs.model == 'array'
        data.profit_mc[i, true] += data.previous_position[i]
      end

      data
    end

      # Generate outputs from engine data
      # @param data [Models::EngineData] Engine data
      # @return [Models::Outputs] Strategy outputs
      def _generate_outputs(data)
      Models::Outputs.new(
        inputs: data.inputs,
        data: data,
        probability_of_profit: data.profit_probability,
        expected_profit: data.expected_profit,
        expected_loss: data.expected_loss,
        strategy_cost: data.cost.sum,
        per_leg_cost: data.cost,
        profit_ranges: data.profit_ranges,
        minimum_return_in_the_domain: data.strategy_profit.min,
        maximum_return_in_the_domain: data.strategy_profit.max,
        implied_volatility: data.implied_volatility,
        in_the_money_probability: data.itm_probability,
        delta: data.delta,
        gamma: data.gamma,
        theta: data.theta,
        vega: data.vega,
        rho: data.rho,
        probability_of_profit_target: data.profit_target_probability,
        probability_of_loss_limit: data.loss_limit_probability,
        profit_target_ranges: data.profit_target_ranges,
        loss_limit_ranges: data.loss_limit_ranges,
      )
      end
    end
  end

end
