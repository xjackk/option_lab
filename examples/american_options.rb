# frozen_string_literal: true

require 'date'
# Use the local code instead of the installed gem
require_relative '../lib/option_lab'

# Example of pricing American options using different models
puts 'American Option Pricing Models Comparison'
puts '----------------------------------------'

# Input parameters
spot_price = 100.0
strike_price = 105.0
risk_free_rate = 0.05
volatility = 0.25
dividend_yield = 0.03
time_to_maturity = 1.0 # 1 year

# Calculate option prices using both models
puts "\nCall Option Comparison:"
puts '----------------------'

# Black-Scholes (European)
bs_call_price = OptionLab::BlackScholes.get_bs_info(
  spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, dividend_yield
).call_price

puts "European Call (Black-Scholes): $#{bs_call_price.round(4)}"

# Cox-Ross-Rubinstein Binomial Tree (American)
crr_call_price = OptionLab.price_binomial(
  'call', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, 100, true, dividend_yield
)

puts "American Call (CRR Binomial): $#{crr_call_price.round(4)}"

# Bjerksund-Stensland (American)
bs_am_call_price = OptionLab.price_american(
  'call', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, dividend_yield
)

puts "American Call (Bjerksund-Stensland): $#{bs_am_call_price.round(4)}"

# Put option prices
puts "\nPut Option Comparison:"
puts '---------------------'

# Black-Scholes (European)
bs_put_price = OptionLab::BlackScholes.get_bs_info(
  spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, dividend_yield
).put_price

puts "European Put (Black-Scholes): $#{bs_put_price.round(4)}"

# Cox-Ross-Rubinstein Binomial Tree (American)
crr_put_price = OptionLab.price_binomial(
  'put', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, 100, true, dividend_yield
)

puts "American Put (CRR Binomial): $#{crr_put_price.round(4)}"

# Bjerksund-Stensland (American)
bs_am_put_price = OptionLab.price_american(
  'put', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, dividend_yield
)

puts "American Put (Bjerksund-Stensland): $#{bs_am_put_price.round(4)}"

# Calculate Greeks for the American put option (which typically has higher early exercise value)
puts "\nAmerican Put Option Greeks Comparison:"
puts '-----------------------------------'

# CRR Binomial Greeks
crr_greeks = OptionLab.get_binomial_greeks(
  'put', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, 100, true, dividend_yield
)

puts 'CRR Binomial Greeks:'
puts "Delta: #{crr_greeks[:delta].round(6)}"
puts "Gamma: #{crr_greeks[:gamma].round(6)}"
puts "Theta: #{crr_greeks[:theta].round(6)}"
puts "Vega: #{crr_greeks[:vega].round(6)}"
puts "Rho: #{crr_greeks[:rho].round(6)}"

# Bjerksund-Stensland Greeks
bs_am_greeks = OptionLab.get_american_greeks(
  'put', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, dividend_yield
)

puts "\nBjerksund-Stensland Greeks:"
puts "Delta: #{bs_am_greeks[:delta].round(6)}"
puts "Gamma: #{bs_am_greeks[:gamma].round(6)}"
puts "Theta: #{bs_am_greeks[:theta].round(6)}"
puts "Vega: #{bs_am_greeks[:vega].round(6)}"
puts "Rho: #{bs_am_greeks[:rho].round(6)}"

# Generate binomial tree for visualization (using smaller number of steps)
tree_data = OptionLab.get_binomial_tree(
  'put', spot_price, strike_price, risk_free_rate, volatility, time_to_maturity, 5, true, dividend_yield
)

puts "\nBinomial Tree Visualization (5 steps):"
puts '-------------------------------------'

# Display tree parameters
puts 'Parameters:'
puts "Spot Price: $#{tree_data[:parameters][:spot_price]}"
puts "Strike Price: $#{tree_data[:parameters][:strike_price]}"
puts "Up Factor: #{tree_data[:parameters][:up_factor].round(4)}"
puts "Down Factor: #{tree_data[:parameters][:down_factor].round(4)}"
puts "Risk-Neutral Probability: #{tree_data[:parameters][:risk_neutral_probability].round(4)}"

puts "\nPrice Tree:"
tree_data[:stock_prices].each_with_index do |step_prices, step|
  puts "Step #{step}: #{step_prices.take(step + 1).map { |p| p.round(2) }.join(', ')}"
end

puts "\nOption Value Tree:"
tree_data[:option_values].each_with_index do |step_values, step|
  puts "Step #{step}: #{step_values.take(step + 1).map { |v| v.round(2) }.join(', ')}"
end

puts "\nEarly Exercise Flags:"
tree_data[:exercise_flags].each_with_index do |step_flags, step|
  puts "Step #{step}: #{step_flags.take(step + 1).join(', ')}"
end

# Early exercise boundary analysis
puts "\nEarly Exercise Boundary Analysis:"
puts '--------------------------------'

# Test a range of spot prices to find the early exercise boundary
puts 'Finding early exercise boundary for American put option at various times to maturity:'
puts "Time\tBoundary"

[0.25, 0.5, 0.75, 1.0].each do |t|
  # Binary search to find boundary
  low = 50.0
  high = strike_price
  tolerance = 0.01

  while (high - low) > tolerance
    mid = (low + high) / 2

    # Test if this spot price should be exercised early
    tree = OptionLab.get_binomial_tree(
      'put', mid, strike_price, risk_free_rate, volatility, t, 25, true, dividend_yield
    )

    if tree[:exercise_flags][0][0]
      # Early exercise is optimal, look higher
      low = mid
    else
      # Early exercise not optimal, look lower
      high = mid
    end
  end

  boundary = (low + high) / 2
  puts "#{t}\t$#{boundary.round(2)}"
end

puts "\nExample completed successfully."
