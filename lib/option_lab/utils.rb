# frozen_string_literal: true

require 'date'
require 'holidays'
require 'numo/narray'

module OptionLab
  module Utils
    # Calendar cache to improve performance
    @holiday_cache = {}
    
    class << self
      # Get number of non-business days between dates
      # @param start_date [Date] Start date
      # @param end_date [Date] End date
      # @param country [String] Country code
      # @return [Integer] Number of non-business days
      def get_nonbusiness_days(start_date, end_date, country = "US")
        if end_date <= start_date
          raise ArgumentError, "End date must be after start date!"
        end
        
        # Create cache key
        cache_key = "#{country}-#{start_date}-#{end_date}"
        
        # Return cached result if available
        return @holiday_cache[cache_key] if @holiday_cache.key?(cache_key)
        
        # Calculate number of days
        n_days = (end_date - start_date).to_i
        
        # Get holidays for the country (default to :us if there's an issue)
        begin
          holidays = Holidays.between(start_date, end_date, country.to_sym)
        rescue Holidays::InvalidRegion
          holidays = Holidays.between(start_date, end_date, :us)
        end
        holiday_dates = holidays.map { |h| h[:date].strftime('%Y-%m-%d') }
        
        # Count non-business days
        nonbusiness_days = 0
        
        n_days.times do |i|
          current_date = start_date + i
          
          # Check if weekend or holiday
          if current_date.saturday? || current_date.sunday? || 
             holiday_dates.include?(current_date.strftime('%Y-%m-%d'))
            nonbusiness_days += 1
          end
        end
        
        # Cache the result
        @holiday_cache[cache_key] = nonbusiness_days
        
        nonbusiness_days
    end
    
      # Get profit/loss data
      # @param outputs [Models::Outputs] Strategy outputs
      # @param leg [Integer, nil] Strategy leg index
      # @return [Array<Numo::DFloat, Numo::DFloat>] Stock prices and profits/losses
      def get_pl(outputs, leg = nil)
        if outputs.data.profit.size > 0 && leg && leg < outputs.data.profit.shape[0]
          [outputs.data.stock_price_array, outputs.data.profit[leg, true]]
        else
          [outputs.data.stock_price_array, outputs.data.strategy_profit]
        end
    end
    
      # Save profit/loss data to CSV
      # @param outputs [Models::Outputs] Strategy outputs
      # @param filename [String, IO] CSV filename or IO object
      # @param leg [Integer, nil] Strategy leg index
      # @return [void]
      def pl_to_csv(outputs, filename = "pl.csv", leg = nil)
        stock_prices, profits = get_pl(outputs, leg)
        
        # Create matrix with stock prices and profits
        data = Numo::DFloat.zeros(stock_prices.size, 2)
        data[true, 0] = stock_prices
        data[true, 1] = profits
        
        # Handle filename as string or IO object
        if filename.is_a?(String)
          # Save to CSV file
          File.open(filename, 'w') do |file|
            file.puts "StockPrice,Profit/Loss"
            
            data.shape[0].times do |i|
              file.puts "#{data[i, 0]},#{data[i, 1]}"
            end
          end
        elsif filename.respond_to?(:puts)
          # Write to IO object
          filename.puts "StockPrice,Profit/Loss"
          
          data.shape[0].times do |i|
            filename.puts "#{data[i, 0]},#{data[i, 1]}"
          end
        else
          raise ArgumentError, "Filename must be a String or an IO object"
        end
      end
    end
  end
end
