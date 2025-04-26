# frozen_string_literal: true

require 'gnuplot'

module OptionLab
  module Plotting
    class << self
      # Plot profit/loss diagram
      # @param outputs [Models::Outputs] Strategy outputs
      # @return [void]
      def plot_pl(outputs)
        st = outputs.data
        inputs = outputs.inputs
        
        if st.strategy_profit.size == 0
          raise RuntimeError, "Before plotting the profit/loss profile diagram, you must run a calculation!"
        end
        
        # Extract data
        stock_prices = st.stock_price_array
        strategy_profit = st.strategy_profit
        zero_line = Numo::DFloat.zeros(stock_prices.size)
        
        # Process strikes and organize marker data
        strike_call_buy = []
        strike_put_buy = []
        zero_call_buy = []
        zero_put_buy = []
        strike_call_sell = []
        strike_put_sell = []
        zero_call_sell = []
        zero_put_sell = []
        
        # Create plot comment
        comment = "Profit/Loss diagram:\n--------------------\n"
        comment += "The vertical green dashed line corresponds to the position "
        comment += "of the stock's spot price. The right and left arrow "
        comment += "markers indicate the strike prices of calls and puts, "
        comment += "respectively, with blue representing long and red representing "
        comment += "short positions."
        
        # Process each strike price
        st.strike.each_with_index do |strike, i|
          next if strike == 0.0
          
          case st.type[i]
          when 'call'
            if st.action[i] == 'buy'
              strike_call_buy << strike
              zero_call_buy << 0.0
            elsif st.action[i] == 'sell'
              strike_call_sell << strike
              zero_call_sell << 0.0
            end
          when 'put'
            if st.action[i] == 'buy'
              strike_put_buy << strike
              zero_put_buy << 0.0
            elsif st.action[i] == 'sell'
              strike_put_sell << strike
              zero_put_sell << 0.0
            end
          end
        end
        
        # Handle profit target and loss limit lines
        if inputs.profit_target
          comment += " The blue dashed line represents the profit target level."
          target_line = Numo::DFloat.new(stock_prices.size).fill(inputs.profit_target)
        end
        
        if inputs.loss_limit
          comment += " The red dashed line represents the loss limit level."
          loss_line = Numo::DFloat.new(stock_prices.size).fill(inputs.loss_limit)
        end
        
        # Print comment
        puts comment
        
        # Create the plot
        begin
          Gnuplot.open do |gp|
            Gnuplot::Plot.new(gp) do |plot|
              plot.title "Options Strategy Profit/Loss"
              plot.xlabel "Stock Price"
              plot.ylabel "Profit/Loss"
              plot.xrange "[#{stock_prices.min}:#{stock_prices.max}]"
              
              # Add zero line
              plot.data << Gnuplot::DataSet.new([stock_prices, zero_line]) do |ds|
                ds.with = "lines"
                ds.linecolor = "violet"
                ds.linewidth = 2
                ds.linetype = 2  # dashed line
                ds.title = "Break-even"
              end
              
              # Add strategy profit line
              plot.data << Gnuplot::DataSet.new([stock_prices, strategy_profit]) do |ds|
                ds.with = "lines"
                ds.linecolor = "black"
                ds.linewidth = 3
                ds.title = "Strategy P/L"
              end
              
              # Add vertical line at current stock price
              plot.data << Gnuplot::DataSet.new(
                ["#{inputs.stock_price}", "#{inputs.stock_price}"], ["#{strategy_profit.min}", "#{strategy_profit.max}"]
              ) do |ds|
                ds.with = "lines"
                ds.linecolor = "green"
                ds.linewidth = 2
                ds.linetype = 2  # dashed line
                ds.title = "Current Price"
              end
              
              # Add profit target line if present
              if inputs.profit_target
                plot.data << Gnuplot::DataSet.new([stock_prices, target_line]) do |ds|
                  ds.with = "lines"
                  ds.linecolor = "blue"
                  ds.linewidth = 2
                  ds.linetype = 2  # dashed line
                  ds.title = "Profit Target"
                end
              end
              
              # Add loss limit line if present
              if inputs.loss_limit
                plot.data << Gnuplot::DataSet.new([stock_prices, loss_line]) do |ds|
                  ds.with = "lines"
                  ds.linecolor = "red"
                  ds.linewidth = 2
                  ds.linetype = 2  # dashed line
                  ds.title = "Loss Limit"
                end
              end
              
              # Add markers for call and put strikes
              if strike_call_buy.any?
                plot.data << Gnuplot::DataSet.new([strike_call_buy, zero_call_buy]) do |ds|
                  ds.with = "points"
                  ds.pointtype = 9  # right arrow
                  ds.pointsize = 2
                  ds.linecolor = "blue"
                  ds.title = "Long Calls"
                end
              end
              
              if strike_put_buy.any?
                plot.data << Gnuplot::DataSet.new([strike_put_buy, zero_put_buy]) do |ds|
                  ds.with = "points"
                  ds.pointtype = 8  # left arrow
                  ds.pointsize = 2
                  ds.linecolor = "blue"
                  ds.title = "Long Puts"
                end
              end
              
              if strike_call_sell.any?
                plot.data << Gnuplot::DataSet.new([strike_call_sell, zero_call_sell]) do |ds|
                  ds.with = "points"
                  ds.pointtype = 9  # right arrow
                  ds.pointsize = 2
                  ds.linecolor = "red"
                  ds.title = "Short Calls"
                end
              end
              
              if strike_put_sell.any?
                plot.data << Gnuplot::DataSet.new([strike_put_sell, zero_put_sell]) do |ds|
                  ds.with = "points"
                  ds.pointtype = 8  # left arrow
                  ds.pointsize = 2
                  ds.linecolor = "red"
                  ds.title = "Short Puts"
                end
              end
            end
          end
        rescue StandardError => e
          puts "Warning: Could not create plot. #{e.message}"
          puts "To use plotting functionality, please ensure gnuplot is installed."
        end
      end
    end
  end
end