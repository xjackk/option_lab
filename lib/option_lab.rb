# frozen_string_literal: true

require_relative 'option_lab/version'
require_relative 'option_lab/configuration'
require_relative 'option_lab/models'
require_relative 'option_lab/black_scholes'
require_relative 'option_lab/binomial_tree'
require_relative 'option_lab/bjerksund_stensland'
require_relative 'option_lab/support'
require_relative 'option_lab/engine'
require_relative 'option_lab/utils'
require_relative 'option_lab/plotting'

# Main module for OptionLab
module OptionLab
  class Error < StandardError; end

  # Public API methods
  class << self
    # Run a strategy calculation
    # @param inputs [Hash, Models::Inputs] Input data for the strategy calculation
    # @return [Models::Outputs] Output data from the strategy calculation
    def run_strategy(inputs)
      Engine.run_strategy(inputs)
    end

    # Plot profit/loss diagram
    # @param outputs [Models::Outputs] Output data from a strategy calculation
    # @return [void]
    def plot_pl(outputs)
      Plotting.plot_pl(outputs)
    end

    # Create price array
    # @param inputs_data [Hash, Models::BlackScholesModelInputs, Models::LaplaceInputs]
    # @param n [Integer] Number of prices to generate
    # @param seed [Integer, nil] Random seed
    # @return [Numo::DFloat] Array of prices
    def create_price_array(inputs_data, n: 100_000, seed: nil)
      Support.create_price_array(inputs_data, n: n, seed: seed)
    end

    # Get profit/loss data
    # @param outputs [Models::Outputs] Output data from a strategy calculation
    # @param leg [Integer, nil] Index of a strategy leg
    # @return [Array<Numo::DFloat, Numo::DFloat>] Array of stock prices and profits/losses
    def get_pl(outputs, leg = nil)
      Utils.get_pl(outputs, leg)
    end

    # Save profit/loss data to CSV
    # @param outputs [Models::Outputs] Output data from a strategy calculation
    # @param filename [String] Name of the CSV file
    # @param leg [Integer, nil] Index of a strategy leg
    # @return [void]
    def pl_to_csv(outputs, filename = 'pl.csv', leg = nil)
      Utils.pl_to_csv(outputs, filename, leg)
    end

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
    def price_binomial(option_type, s0, x, r, volatility, years_to_maturity, n_steps = 100, is_american = true, dividend_yield = 0.0)
      BinomialTree.price_option(option_type, s0, x, r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)
    end

    # Get binomial tree data for visualization and analysis
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
    def get_binomial_tree(option_type, s0, x, r, volatility, years_to_maturity, n_steps = 15, is_american = true, dividend_yield = 0.0)
      BinomialTree.get_tree(option_type, s0, x, r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)
    end

    # Calculate option Greeks using the CRR binomial tree model
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
    def get_binomial_greeks(option_type, s0, x, r, volatility, years_to_maturity, n_steps = 100, is_american = true, dividend_yield = 0.0)
      BinomialTree.get_greeks(option_type, s0, x, r, volatility, years_to_maturity, n_steps, is_american, dividend_yield)
    end

    # Price an option using the Bjerksund-Stensland model
    # @param option_type [String] 'call' or 'put'
    # @param s0 [Float] Spot price
    # @param x [Float] Strike price
    # @param r [Float] Risk-free interest rate
    # @param volatility [Float] Volatility
    # @param years_to_maturity [Float] Time to maturity in years
    # @param dividend_yield [Float] Continuous dividend yield
    # @return [Float] Option price
    def price_american(option_type, s0, x, r, volatility, years_to_maturity, dividend_yield = 0.0)
      BjerksundStensland.price_option(option_type, s0, x, r, volatility, years_to_maturity, dividend_yield)
    end

    # Calculate option Greeks using the Bjerksund-Stensland model
    # @param option_type [String] 'call' or 'put'
    # @param s0 [Float] Spot price
    # @param x [Float] Strike price
    # @param r [Float] Risk-free interest rate
    # @param volatility [Float] Volatility
    # @param years_to_maturity [Float] Time to maturity in years
    # @param dividend_yield [Float] Continuous dividend yield
    # @return [Hash] Option Greeks (delta, gamma, theta, vega, rho)
    def get_american_greeks(option_type, s0, x, r, volatility, years_to_maturity, dividend_yield = 0.0)
      BjerksundStensland.get_greeks(option_type, s0, x, r, volatility, years_to_maturity, dividend_yield)
    end
  end
end