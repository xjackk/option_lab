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
end

# Helper methods for tests
module TestHelpers

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
    }
  end

end
