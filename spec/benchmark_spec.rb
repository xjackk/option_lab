# frozen_string_literal: true

require 'benchmark'
require 'option_lab'

# Skip strategy validation for benchmark tests
OptionLab.configure do |config|
  config.skip_strategy_validation = true
end

# Benchmark different strategies
puts 'OptionLabRB Performance Benchmarks'
puts '================================'

# Define test inputs
COVERED_CALL = {
  stock_price: 168.99,
  volatility: 0.483,
  interest_rate: 0.045,
  start_date: Date.new(2023, 1, 16),
  target_date: Date.new(2023, 2, 17),
  min_stock: 68.99,
  max_stock: 268.99,
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

VERTICAL_SPREAD = {
  stock_price: 168.99,
  volatility: 0.483,
  interest_rate: 0.045,
  start_date: Date.new(2023, 1, 16),
  target_date: Date.new(2023, 2, 17),
  min_stock: 68.99,
  max_stock: 268.99,
  strategy: [
    {
      type: 'call',
      strike: 165.0,
      premium: 12.65,
      n: 100,
      action: 'buy',
      expiration: Date.new(2023, 2, 17),
    },
    {
      type: 'call',
      strike: 170.0,
      premium: 9.9,
      n: 100,
      action: 'sell',
      expiration: Date.new(2023, 2, 17),
    },
  ],
}

# Create a complex strategy with many legs
COMPLEX_STRATEGY = {
  stock_price: 168.99,
  volatility: 0.483,
  interest_rate: 0.045,
  start_date: Date.new(2023, 1, 16),
  target_date: Date.new(2023, 2, 17),
  min_stock: 68.99,
  max_stock: 268.99,
  strategy: [
    { type: 'stock', n: 100, action: 'buy' },
    {
      type: 'call',
      strike: 165.0,
      premium: 12.65,
      n: 100,
      action: 'buy',
      expiration: Date.new(2023, 2, 17),
    },
    {
      type: 'call',
      strike: 170.0,
      premium: 9.9,
      n: 100,
      action: 'sell',
      expiration: Date.new(2023, 2, 17),
    },
    {
      type: 'call',
      strike: 180.0,
      premium: 5.5,
      n: 100,
      action: 'sell',
      expiration: Date.new(2023, 2, 17),
    },
    {
      type: 'call',
      strike: 190.0,
      premium: 2.2,
      n: 100,
      action: 'buy',
      expiration: Date.new(2023, 2, 17),
    },
  ],
}

# Run benchmarks
puts "\nBenchmarking strategy calculation times:"
Benchmark.bm(20) do |x|
  x.report('Covered Call:') { OptionLab.run_strategy(COVERED_CALL) }
  x.report('Vertical Spread:') { OptionLab.run_strategy(VERTICAL_SPREAD) }
  x.report('Complex Strategy:') { OptionLab.run_strategy(COMPLEX_STRATEGY) }
end

# Benchmark price array generation
puts "\nBenchmarking price array generation:"
Benchmark.bm(20) do |x|
  x.report('Normal (n=10k):') do
    bs_inputs = OptionLab::Models::BlackScholesModelInputs.new(
      stock_price: 168.99,
      volatility: 0.483,
      interest_rate: 0.045,
      years_to_target_date: 24.0 / 365,
    )
    OptionLab.create_price_array(bs_inputs, n: 10_000)
  end

  x.report('Normal (n=100k):') do
    bs_inputs = OptionLab::Models::BlackScholesModelInputs.new(
      stock_price: 168.99,
      volatility: 0.483,
      interest_rate: 0.045,
      years_to_target_date: 24.0 / 365,
    )
    OptionLab.create_price_array(bs_inputs, n: 100_000)
  end

  x.report('Laplace (n=10k):') do
    laplace_inputs = OptionLab::Models::LaplaceInputs.new(
      stock_price: 168.99,
      volatility: 0.483,
      years_to_target_date: 24.0 / 365,
      mu: 0.05,
    )
    OptionLab.create_price_array(laplace_inputs, n: 10_000)
  end
end

# Benchmark Monte Carlo simulation
puts "\nBenchmarking Monte Carlo simulation strategies:"
Benchmark.bm(20) do |x|
  x.report('MC w/ 10k samples:') do
    bs_inputs = OptionLab::Models::BlackScholesModelInputs.new(
      stock_price: 168.99,
      volatility: 0.483,
      interest_rate: 0.045,
      years_to_target_date: 24.0 / 365,
    )
    prices = OptionLab.create_price_array(bs_inputs, n: 10_000, seed: 42)

    mc_input = COVERED_CALL.merge(
      model: 'array',
      array: prices,
    )

    OptionLab.run_strategy(mc_input)
  end

  x.report('MC w/ 100k samples:') do
    bs_inputs = OptionLab::Models::BlackScholesModelInputs.new(
      stock_price: 168.99,
      volatility: 0.483,
      interest_rate: 0.045,
      years_to_target_date: 24.0 / 365,
    )
    prices = OptionLab.create_price_array(bs_inputs, n: 100_000, seed: 42)

    mc_input = COVERED_CALL.merge(
      model: 'array',
      array: prices,
    )

    OptionLab.run_strategy(mc_input)
  end
end

# Benchmark different price array sizes
puts "\nBenchmarking different price array sizes (step size):"
Benchmark.bm(20) do |x|
  x.report('Step $0.01 (10k pts):') do
    modified_input = COVERED_CALL.dup
    modified_input[:min_stock] = 100.0
    modified_input[:max_stock] = 200.0
    OptionLab.run_strategy(modified_input)
  end

  x.report('Step $0.05 (2k pts):') do
    modified_input = COVERED_CALL.dup
    modified_input[:min_stock] = 100.0
    modified_input[:max_stock] = 200.0

    # Override create_price_seq to use larger step
    original_method = OptionLab::Support.method(:create_price_seq)

    begin
      OptionLab::Support.define_singleton_method(:create_price_seq) do |min_price, max_price|
        Numo::DFloat.new(((max_price - min_price) / 0.05).to_i + 1).seq(min_price, 0.05).round
      end

      OptionLab.run_strategy(modified_input)
    ensure
      # Restore original method
      OptionLab::Support.define_singleton_method(:create_price_seq, original_method)
    end
  end
end

# Reset configuration after benchmarks
OptionLab.reset_configuration

puts "\nAll benchmarks completed!"