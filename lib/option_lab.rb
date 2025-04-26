# frozen_string_literal: true

require_relative "option_lab/version"
require_relative "option_lab/models"
require_relative "option_lab/black_scholes"
require_relative "option_lab/support"
require_relative "option_lab/engine"
require_relative "option_lab/utils"
require_relative "option_lab/plotting"

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
    def pl_to_csv(outputs, filename = "pl.csv", leg = nil)
      Utils.pl_to_csv(outputs, filename, leg)
    end
  end
end
