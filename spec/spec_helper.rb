# frozen_string_literal: true

require 'option_lab'
require 'date'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration between examples to ensure isolated tests
  config.after(:each) do
    # Make sure we're calling the class method with reset_configuration, not the instance method
    OptionLab.reset_configuration
  end
end

# Helper methods for tests
module TestHelpers
  # Test configuration helpers
  def self.configure_for_empty_strategy_test
    OptionLab.reset_configuration
    OptionLab.configure do |config|
      config.skip_strategy_validation = false
      config.check_closed_positions_only = false
      config.check_expiration_dates_only = false
      config.check_date_target_mixing_only = false
      config.check_dates_or_days_only = false
      config.check_array_model_only = false
    end
  end

  def self.configure_for_closed_positions_test
    OptionLab.reset_configuration
    OptionLab.configure do |config|
      config.skip_strategy_validation = false
      config.check_closed_positions_only = true
      config.check_expiration_dates_only = false
      config.check_date_target_mixing_only = false
      config.check_dates_or_days_only = false
      config.check_array_model_only = false
    end
  end

  def self.configure_for_expiration_test
    OptionLab.reset_configuration
    OptionLab.configure do |config|
      config.skip_strategy_validation = false
      config.check_closed_positions_only = false
      config.check_expiration_dates_only = true
      config.check_date_target_mixing_only = false
      config.check_dates_or_days_only = false
      config.check_array_model_only = false
    end
  end

  def self.configure_for_date_mixing_test
    OptionLab.reset_configuration
    OptionLab.configure do |config|
      config.skip_strategy_validation = false
      config.check_closed_positions_only = false
      config.check_expiration_dates_only = false
      config.check_date_target_mixing_only = true
      config.check_dates_or_days_only = false
      config.check_array_model_only = false
    end
  end

  def self.configure_for_dates_or_days_test
    OptionLab.reset_configuration
    OptionLab.configure do |config|
      config.skip_strategy_validation = false
      config.check_closed_positions_only = false
      config.check_expiration_dates_only = false
      config.check_date_target_mixing_only = false
      config.check_dates_or_days_only = true
      config.check_array_model_only = false
    end
  end

  def self.configure_for_array_model_test
    OptionLab.reset_configuration
    OptionLab.configure do |config|
      config.skip_strategy_validation = false
      config.check_closed_positions_only = false
      config.check_expiration_dates_only = false
      config.check_date_target_mixing_only = false
      config.check_dates_or_days_only = false
      config.check_array_model_only = true
    end
  end

  def self.covered_call_fixture
    {
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
      skip_strategy_validation: true
    }
  end

  def self.vertical_spread_fixture
    {
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
      skip_strategy_validation: true
    }
  end

  def self.naked_call_fixture
    {
      stock_price: 164.04,
      volatility: 0.272,
      interest_rate: 0.0002,
      start_date: Date.new(2021, 11, 22),
      target_date: Date.new(2021, 12, 17),
      min_stock: 82.02,
      max_stock: 246.06,
      profit_target: 100.0,
      loss_limit: -100.0,
      strategy: [
        {
          type: 'call',
          strike: 175.00,
          premium: 1.15,
          n: 100,
          action: 'sell',
        },
      ],
      skip_strategy_validation: true
    }
  end
end