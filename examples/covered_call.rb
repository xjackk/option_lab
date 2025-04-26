# frozen_string_literal: true

require 'date'
# Use the local code instead of the installed gem
require_relative '../lib/option_lab'

# Example of a covered call strategy
# A covered call involves owning the underlying stock and selling call options against it

# Step 1: Define input parameters
input_data = {
  stock_price: 168.99,               # Current stock price
  volatility: 0.483,                 # Annualized volatility (48.3%)
  interest_rate: 0.045,              # Annualized risk-free interest rate (4.5%)
  start_date: Date.new(2023, 1, 16), # Strategy start date
  target_date: Date.new(2023, 2, 17), # Strategy target date
  min_stock: 68.99,                  # Minimum stock price for analysis
  max_stock: 268.99,                 # Maximum stock price for analysis

  # The covered call strategy is defined with two legs:
  # 1. Long 100 shares of stock
  # 2. Short 1 call option with strike price 185.0 and premium 4.1
  strategy: [
    { type: 'stock', n: 100, action: 'buy' },
    {
      type: 'call',
      strike: 185.0,
      premium: 4.1,
      n: 100,
      action: 'sell',
      expiration: Date.new(2023, 2, 17),
    },
  ],
}

# Step 2: Run the strategy calculation
puts 'Calculating strategy outcomes...'
outputs = OptionLab.run_strategy(input_data)

# Step 3: Print the results
puts "\nCovered Call Strategy Results:"
puts '------------------------------'
puts outputs

# Step 4: Extract and display key metrics
puts "\nKey Metrics:"
puts "Probability of Profit: #{(outputs.probability_of_profit * 100).round(2)}%"
puts "Expected Profit (when profitable): $#{outputs.expected_profit}" if outputs.expected_profit
puts "Expected Loss (when unprofitable): $#{outputs.expected_loss}" if outputs.expected_loss
puts "Strategy Cost: $#{outputs.strategy_cost}"
puts "Maximum Return: $#{outputs.maximum_return_in_the_domain}"
puts "Minimum Return: $#{outputs.minimum_return_in_the_domain}"

# Step 5: Print Greeks for each leg
puts "\nGreeks by Strategy Leg:"
puts 'Leg 1 (Stock):'
puts "  Delta: #{outputs.delta[0]}"

puts 'Leg 2 (Call Option):'
puts "  Delta: #{outputs.delta[1]}"
puts "  Gamma: #{outputs.gamma[1]}"
puts "  Theta: #{outputs.theta[1]}"
puts "  Vega: #{outputs.vega[1]}"
puts "  Rho: #{outputs.rho[1]}"
puts "  Implied Volatility: #{(outputs.implied_volatility[1] * 100).round(2)}%"
puts "  ITM Probability: #{(outputs.in_the_money_probability[1] * 100).round(2)}%"

# Step 6: Export P/L data to CSV
csv_filename = 'covered_call_pl.csv'
OptionLab.pl_to_csv(outputs, csv_filename)
puts "\nProfit/Loss data exported to #{csv_filename}"

# Step 7: Plot the profit/loss diagram
puts "\nGenerating profit/loss diagram..."
OptionLab.plot_pl(outputs)
puts 'Plot displayed. Close the plot window to exit.'
