# frozen_string_literal: true

require 'unicode_plot'

module OptionLab
  module Plotting
    class << self
      # Plot profit/loss diagram
      # @param outputs [Models::Outputs] Strategy outputs
      # @return [void]
      def plot_pl(outputs)
        st = outputs.data
        inputs = outputs.inputs

        if st.strategy_profit.empty?
          raise RuntimeError, 'Before plotting the profit/loss profile diagram, you must run a calculation!'
        end

        # Extract data
        stock_prices = st.stock_price_array
        strategy_profit = st.strategy_profit

        # Print explanation for the plot
        comment = "Profit/Loss diagram:\n--------------------\n"
        comment += "The vertical line (|) corresponds to the stock's current price (#{inputs.stock_price}).\n"
        comment += "Break-even points are where the line crosses zero.\n"

        # Process strikes and add to comment
        call_buy_strikes = []
        put_buy_strikes = []
        call_sell_strikes = []
        put_sell_strikes = []

        st.strike.each_with_index do |strike, i|
          next if strike == 0.0

          case st.type[i]
          when 'call'
            if st.action[i] == 'buy'
              call_buy_strikes << strike
            elsif st.action[i] == 'sell'
              call_sell_strikes << strike
            end
          when 'put'
            if st.action[i] == 'buy'
              put_buy_strikes << strike
            elsif st.action[i] == 'sell'
              put_sell_strikes << strike
            end
          end
        end

        if call_buy_strikes.any?
          comment += "Long Call Strikes: #{call_buy_strikes.join(', ')}\n"
        end

        if call_sell_strikes.any?
          comment += "Short Call Strikes: #{call_sell_strikes.join(', ')}\n"
        end

        if put_buy_strikes.any?
          comment += "Long Put Strikes: #{put_buy_strikes.join(', ')}\n"
        end

        if put_sell_strikes.any?
          comment += "Short Put Strikes: #{put_sell_strikes.join(', ')}\n"
        end

        # Handle profit target and loss limit
        if inputs.profit_target
          comment += "Profit Target: $#{inputs.profit_target}\n"
        end

        if inputs.loss_limit
          comment += "Loss Limit: $#{inputs.loss_limit}\n"
        end

        # Print comment
        puts comment

        # Create LineChart with stock prices and strategy profit
        plot = UnicodePlot.lineplot(
          stock_prices.to_a,
          strategy_profit.to_a,
          title: 'Options Strategy Profit/Loss',
          xlabel: 'Stock Price',
          ylabel: 'Profit/Loss'
        )

        # Add horizontal zero line for break-even
        zero_line = Array.new(stock_prices.size, 0)
        plot = UnicodePlot.lineplot!(
          plot,
          stock_prices.to_a,
          zero_line,
          name: 'Break-even',
          color: :magenta
        )

        # Add vertical line at current stock price
        # Find index closest to current stock price
        current_price_idx = stock_prices.to_a.index { |p| p >= inputs.stock_price } || (stock_prices.size / 2)
        current_x = [stock_prices[current_price_idx], stock_prices[current_price_idx]]
        current_y = [strategy_profit.min, strategy_profit.max]

        plot = UnicodePlot.lineplot!(
          plot,
          current_x,
          current_y,
          name: 'Current Price',
          color: :green
        )

        # Add profit target line if specified
        if inputs.profit_target
          target_line = Array.new(stock_prices.size, inputs.profit_target)
          plot = UnicodePlot.lineplot!(
            plot,
            stock_prices.to_a,
            target_line,
            name: 'Profit Target',
            color: :blue
          )
        end

        # Add loss limit line if specified
        if inputs.loss_limit
          loss_line = Array.new(stock_prices.size, inputs.loss_limit)
          plot = UnicodePlot.lineplot!(
            plot,
            stock_prices.to_a,
            loss_line,
            name: 'Loss Limit',
            color: :red
          )
        end

        # Display the plot
        puts plot

        # Print break-even points
        break_even_points = find_break_even_points(stock_prices.to_a, strategy_profit.to_a)
        if break_even_points.any?
          puts "\nBreak-even prices: #{break_even_points.map { |p| sprintf('$%.2f', p) }.join(', ')}"
        else
          puts "\nNo break-even points found in the analyzed price range."
        end

        # Print max profit/loss in range
        puts "Maximum profit in range: $#{strategy_profit.max.round(2)}"
        puts "Maximum loss in range: $#{strategy_profit.min.round(2)}"
      end

      private

      # Find approximate break-even points where profit/loss crosses zero
      # @param prices [Array<Float>] Array of stock prices
      # @param profits [Array<Float>] Array of profit/loss values
      # @return [Array<Float>] Approximate break-even points
      def find_break_even_points(prices, profits)
        break_even_points = []

        # Find where profit crosses zero (sign changes)
        (0...profits.size - 1).each do |i|
          if (profits[i] <= 0 && profits[i + 1] > 0) || (profits[i] >= 0 && profits[i + 1] < 0)
            # Linear interpolation to find more accurate break-even point
            if profits[i] != profits[i + 1] # Avoid division by zero
              ratio = profits[i].abs / (profits[i].abs + profits[i + 1].abs)
              break_even = prices[i] + ratio * (prices[i + 1] - prices[i])
              break_even_points << break_even.round(2)
            else
              # If same profit (unlikely but possible), use midpoint
              break_even_points << ((prices[i] + prices[i + 1]) / 2).round(2)
            end
          end
        end

        break_even_points
      end
    end
  end
end