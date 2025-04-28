# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OptionLab::Configuration do
  describe 'configuration' do
    after(:each) do
      # Reset configuration after each test
      OptionLab.reset_configuration
    end

    it 'creates a configuration with default values' do
      config = OptionLab.configuration
      expect(config).to be_a(OptionLab::Configuration)
      expect(config.skip_strategy_validation).to eq(false)
      expect(config.check_closed_positions_only).to eq(false)
      expect(config.check_expiration_dates_only).to eq(false)
      expect(config.check_date_target_mixing_only).to eq(false)
      expect(config.check_dates_or_days_only).to eq(false)
      expect(config.check_array_model_only).to eq(false)
    end

    it 'allows configuration to be updated' do
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
        config.check_closed_positions_only = true
      end

      config = OptionLab.configuration
      expect(config.skip_strategy_validation).to eq(true)
      expect(config.check_closed_positions_only).to eq(true)
      expect(config.check_expiration_dates_only).to eq(false)
    end

    it 'resets configuration to default values' do
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
        config.check_closed_positions_only = true
      end

      OptionLab.reset_configuration
      config = OptionLab.configuration
      expect(config.skip_strategy_validation).to eq(false)
      expect(config.check_closed_positions_only).to eq(false)
    end
  end
end

RSpec.describe OptionLab::Models::Inputs do
  describe 'validation with configuration' do
    let(:valid_attributes) do
      {
        stock_price: 100.0,
        volatility: 0.2,
        interest_rate: 0.05,
        min_stock: 50.0,
        max_stock: 150.0,
        start_date: Date.today,
        target_date: Date.today + 30,
        strategy: [
          { type: 'call', strike: 105.0, premium: 3.0, n: 10, action: 'buy' },
        ],
      }
    end

    after(:each) do
      # Reset configuration after each test
      OptionLab.reset_configuration
    end

    it 'skips strategy validation when skip_strategy_validation is true' do
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end

      # This would normally fail with 'strategy must not be empty'
      attributes = valid_attributes.merge(strategy: [])
      expect { described_class.new(attributes) }.not_to raise_error
    end

    it 'only checks for closed positions when check_closed_positions_only is true' do
      OptionLab.configure do |config|
        config.check_closed_positions_only = true
      end

      # This should still fail with multiple closed positions
      attributes = valid_attributes.merge(
        strategy: [
          { type: 'closed', prev_pos: 100.0 },
          { type: 'closed', prev_pos: 200.0 },
        ],
      )
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, "Only one position of type 'closed' is allowed!")

      # But it should allow an empty strategy since we're only checking closed positions
      attributes = valid_attributes.merge(strategy: [])
      expect { described_class.new(attributes) }.not_to raise_error
    end

    it 'only checks expiration dates when check_expiration_dates_only is true' do
      OptionLab.configure do |config|
        config.check_expiration_dates_only = true
      end

      # This should still fail with invalid expiration date
      attributes = valid_attributes.merge(
        target_date: Date.today + 30,
        strategy: [
          {
            type: 'call',
            strike: 105.0,
            premium: 3.0,
            n: 10,
            action: 'buy',
            expiration: Date.today + 20,
          },
        ],
      )
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'Expiration dates must be after or on target date!')

      # But it should allow an empty strategy since we're only checking expiration dates
      attributes = valid_attributes.merge(strategy: [])
      expect { described_class.new(attributes) }.not_to raise_error
    end

    it 'validates instance level skip_strategy_validation flag' do
      # This would normally fail with 'strategy must not be empty'
      attributes = valid_attributes.merge(strategy: [], skip_strategy_validation: true)
      expect { described_class.new(attributes) }.not_to raise_error
    end
  end
end
