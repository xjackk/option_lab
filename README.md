# OptionLab

OptionLab is a lightweight Ruby library designed to provide quick evaluation of options trading strategies.
It aims to be a direct port of the popular Python library - [OptionLab](https://github.com/rgaveiga/optionlab)

## Features

- Calculate profit/loss profiles for options strategies
- Estimate probability of profit using Black-Scholes or custom models
- Calculate option Greeks (Delta, Gamma, Theta, Vega, Rho)
- Generate profit/loss diagrams
- Support for complex multi-leg strategies
- Handle stock positions and previously closed trades
- Support for different dividend yield and interest rate scenarios
- Business day calculations across different countries

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'option_lab'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install option_lab
```

## Requirements

OptionLab requires:

- Ruby 3.3.0 or higher
- numo-narray gem for numerical computations
- distribution gem for statistical calculations
- gnuplot gem for visualization

## Basic Usage

The evaluation of a strategy is done by calling the `run_strategy` method provided by the library. This method receives the input data as a Ruby hash or an `Inputs` object.

Here's an example of evaluating a naked call strategy:

```ruby
require 'option_lab'

# Define the strategy
input_data = {
  stock_price: 164.04,
  start_date: Date.new(2023, 11, 22),
  target_date: Date.new(2023, 12, 17),
  volatility: 0.272,
  interest_rate: 0.0002,
  min_stock: 120,
  max_stock: 200,
  strategy: [
    {
      type: "call",
      strike: 175.0,
      premium: 1.15,
      n: 100,
      action: "sell"
    }
  ]
}

# Run the strategy calculation
outputs = OptionLab.run_strategy(input_data)

# Export P/L data to CSV
OptionLab.pl_to_csv(outputs, filename: "covered_call_pl.csv")
```

## Analyzing Results

The `Outputs` object returned by `run_strategy` contains a wealth of information:

```ruby
# Key probability metrics
probability_of_profit = outputs.probability_of_profit
profit_ranges = outputs.profit_ranges
expected_profit = outputs.expected_profit
expected_loss = outputs.expected_loss

# Strategy costs
strategy_cost = outputs.strategy_cost
per_leg_cost = outputs.per_leg_cost

# Returns
min_return = outputs.minimum_return_in_the_domain
max_return = outputs.maximum_return_in_the_domain

# Option Greeks
delta = outputs.delta
gamma = outputs.gamma
theta = outputs.theta
vega = outputs.vega
rho = outputs.rho

# Print all metrics
puts outputs
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer

This is free software and is provided as is. The author makes no guarantee that its results are accurate and is not responsible for any losses caused by the use of the code.

Options are risky derivatives and, like any other type of financial vehicle, trading options requires due diligence. This code is provided for educational and research purposes only.

# Print the results
puts outputs

# Plot the profit/loss diagram
OptionLab.plot_pl(outputs)
```

## Common Strategies

OptionLab supports all standard options strategies, including:

- Covered calls
- Naked puts
- Bull/bear spreads
- Straddles/strangles
- Iron condors
- Butterflies
- Calendar spreads
- And more...

## Advanced Usage

The library also allows for more advanced use cases, such as:

```ruby
# Create a custom distribution model
bs_inputs = OptionLab::Models::BlackScholesModelInputs.new(
  stock_price: 168.99,
  volatility: 0.483,
  interest_rate: 0.045,
  years_to_target_date: 24.0 / 365
)

# Generate price array with 10,000 samples
prices = OptionLab.create_price_array(bs_inputs, n: 10_000, seed: 42)

# Run a strategy with the custom price array
input_data = {
  stock_price: 168.99,
  volatility: 0.483,
  interest_rate: 0.045,
  min_stock: 120,
  max_stock: 200,
  model: "array",
  array: prices,
  strategy: [
    { type: "stock", n: 100, action: "buy" },
    {
      type: "call",
      strike: 185.0,
      premium: 4.1,
      n: 100,
      action: "sell"
    }
  ]
}

outputs = OptionLab.run_strategy(input_data)
