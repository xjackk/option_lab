# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OptionLab::Models do
  describe OptionLab::Models::Stock do
    it 'initializes with valid attributes' do
      stock = described_class.new(n: 100, action: 'buy')
      expect(stock.n).to eq(100)
      expect(stock.action).to eq('buy')
      expect(stock.type).to eq('stock')
    end

    it 'raises error when n is not positive' do
      expect { described_class.new(n: 0, action: 'buy') }.to raise_error(ArgumentError, 'n must be positive')
    end

    it 'raises error when action is invalid' do
      expect { described_class.new(n: 100, action: 'invalid') }.to raise_error(ArgumentError, "action must be 'buy' or 'sell'")
    end
  end

  describe OptionLab::Models::Option do
    it 'initializes with valid attributes' do
      option = described_class.new(
        type: 'call',
        strike: 100.0,
        premium: 5.0,
        n: 10,
        action: 'buy',
        expiration: Date.today + 30,
      )
      expect(option.type).to eq('call')
      expect(option.strike).to eq(100.0)
      expect(option.premium).to eq(5.0)
      expect(option.n).to eq(10)
      expect(option.action).to eq('buy')
      expect(option.expiration).to be_a(Date)
    end

    it 'raises error when type is invalid' do
      expect do
        described_class.new(
          type: 'invalid',
          strike: 100.0,
          premium: 5.0,
          n: 10,
          action: 'buy',
        )
      end.to raise_error(ArgumentError, "type must be 'call' or 'put'")
    end

    it 'raises error when strike is not positive' do
      expect do
        described_class.new(
          type: 'call',
          strike: 0,
          premium: 5.0,
          n: 10,
          action: 'buy',
        )
      end.to raise_error(ArgumentError, 'strike must be positive')
    end

    it 'raises error when premium is not positive' do
      expect do
        described_class.new(
          type: 'call',
          strike: 100.0,
          premium: 0,
          n: 10,
          action: 'buy',
        )
      end.to raise_error(ArgumentError, 'premium must be positive')
    end

    it 'raises error when expiration is an integer <= 0' do
      expect do
        described_class.new(
          type: 'call',
          strike: 100.0,
          premium: 5.0,
          n: 10,
          action: 'buy',
          expiration: 0,
        )
      end.to raise_error(ArgumentError, 'If expiration is an integer, it must be greater than 0')
    end
  end

  describe OptionLab::Models::ClosedPosition do
    it 'initializes with valid attributes' do
      closed = described_class.new(prev_pos: 100.0)
      expect(closed.prev_pos).to eq(100.0)
      expect(closed.type).to eq('closed')
    end

    it 'raises error when prev_pos is not a number' do
      expect { described_class.new(prev_pos: 'not a number') }.to raise_error(ArgumentError, 'prev_pos must be a number')
    end
  end

  describe OptionLab::Models::Inputs do
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

    it 'initializes with valid attributes' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      inputs = described_class.new(valid_attributes)
      expect(inputs.stock_price).to eq(100.0)
      expect(inputs.volatility).to eq(0.2)
      expect(inputs.interest_rate).to eq(0.05)
      expect(inputs.min_stock).to eq(50.0)
      expect(inputs.max_stock).to eq(150.0)
      expect(inputs.strategy).to be_an(Array)
      expect(inputs.strategy.first).to be_a(OptionLab::Models::Option)
    end

    it 'sets default values' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      inputs = described_class.new(valid_attributes)
      expect(inputs.dividend_yield).to eq(0.0)
      expect(inputs.opt_commission).to eq(0.0)
      expect(inputs.stock_commission).to eq(0.0)
      expect(inputs.discard_nonbusiness_days).to eq(true)
      expect(inputs.business_days_in_year).to eq(252)
      expect(inputs.country).to eq('US')
      expect(inputs.days_to_target_date).to eq(0)
      expect(inputs.model).to eq('black-scholes')
      expect(inputs.array.size).to eq(0)
    end

    it 'raises error when stock_price is not positive' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      attributes = valid_attributes.merge(stock_price: 0)
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'stock_price must be positive')
    end

    it 'raises error when volatility is negative' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      attributes = valid_attributes.merge(volatility: -0.1)
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'volatility must be non-negative')
    end

    it 'raises error when interest_rate is negative' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      attributes = valid_attributes.merge(interest_rate: -0.1)
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'interest_rate must be non-negative')
    end

    it 'raises error when min_stock is negative' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      attributes = valid_attributes.merge(min_stock: -50.0)
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'min_stock must be non-negative')
    end

    it 'raises error when max_stock is negative' do
      # Set skip_strategy_validation to true for this test to avoid validation errors
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      attributes = valid_attributes.merge(max_stock: -150.0)
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'max_stock must be non-negative')
    end

    it 'raises error when strategy is empty' do
      TestHelpers.configure_for_empty_strategy_test
      attributes = valid_attributes.merge(strategy: [])
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'strategy must not be empty')
    end

    it 'raises error when multiple closed positions are provided' do
      TestHelpers.configure_for_closed_positions_test
      attributes = valid_attributes.merge(
        strategy: [
          { type: 'closed', prev_pos: 100.0 },
          { type: 'closed', prev_pos: 200.0 },
        ],
      )
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, "Only one position of type 'closed' is allowed!")
    end

    it 'raises error when expiration date is before target date' do
      TestHelpers.configure_for_expiration_test
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
    end

    it 'raises error when start date is after or equal to target date' do
      # Configure for validating only dates
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
      
      attributes = valid_attributes.merge(
        start_date: Date.today,
        target_date: Date.today,
      )
      # We need to run validate_start_target_dates! directly to test this validation
      inputs = described_class.new(attributes)
      expect { inputs.validate_start_target_dates! }.to raise_error(ArgumentError, 'Start date must be before target date!')
    end

    it 'raises error when mixing expiration with days_to_target_date' do
      TestHelpers.configure_for_date_mixing_test
      attributes = valid_attributes.merge(
        start_date: nil,
        target_date: nil,
        days_to_target_date: 30,
        strategy: [
          {
            type: 'call',
            strike: 105.0,
            premium: 3.0,
            n: 10,
            action: 'buy',
            expiration: Date.today + 30,
          },
        ],
      )
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, "You can't mix a strategy expiration with a days_to_target_date.")
    end

    it 'raises error when neither dates nor days_to_target_date are provided' do
      TestHelpers.configure_for_dates_or_days_test
      attributes = valid_attributes.merge(
        start_date: nil,
        target_date: nil,
        days_to_target_date: 0,
      )
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, 'Either start_date and target_date or days_to_maturity must be provided')
    end

    it 'raises error when model is array but no array is provided' do
      TestHelpers.configure_for_array_model_test
      attributes = valid_attributes.merge(
        model: 'array',
        array: [],
      )
      expect { described_class.new(attributes) }.to raise_error(ArgumentError, "Array of terminal stock prices must be provided if model is 'array'.")
    end
  end

  describe OptionLab::Models::Outputs do
    before(:each) do
      # Make sure validation is skipped for all tests in this group
      OptionLab.configure do |config|
        config.skip_strategy_validation = true
      end
    end
    
    it 'initializes with valid attributes' do
      outputs = described_class.new(
        inputs: OptionLab::Models::Inputs.new(TestHelpers.covered_call_fixture),
        data: OptionLab::Models::EngineDataResults.new,
        probability_of_profit: 0.75,
        profit_ranges: [[100.0, 200.0]],
        expected_profit: 500.0,
        expected_loss: -200.0,
        per_leg_cost: [100.0, 200.0],
        strategy_cost: 300.0,
        minimum_return_in_the_domain: -500.0,
        maximum_return_in_the_domain: 1000.0,
        implied_volatility: [0.0, 0.2],
        in_the_money_probability: [1.0, 0.3],
        delta: [1.0, -0.3],
        gamma: [0.0, 0.01],
        theta: [0.0, 0.02],
        vega: [0.0, 0.15],
        rho: [0.0, -0.02],
      )

      expect(outputs.probability_of_profit).to eq(0.75)
      expect(outputs.profit_ranges).to eq([[100.0, 200.0]])
      expect(outputs.expected_profit).to eq(500.0)
      expect(outputs.expected_loss).to eq(-200.0)
      expect(outputs.per_leg_cost).to eq([100.0, 200.0])
      expect(outputs.strategy_cost).to eq(300.0)
    end

    it 'sets default values' do
      outputs = described_class.new(
        inputs: OptionLab::Models::Inputs.new(TestHelpers.covered_call_fixture),
        data: OptionLab::Models::EngineDataResults.new,
        probability_of_profit: 0.75,
        profit_ranges: [[100.0, 200.0]],
        per_leg_cost: [100.0, 200.0],
        strategy_cost: 300.0,
        minimum_return_in_the_domain: -500.0,
        maximum_return_in_the_domain: 1000.0,
        implied_volatility: [0.0, 0.2],
        in_the_money_probability: [1.0, 0.3],
        delta: [1.0, -0.3],
        gamma: [0.0, 0.01],
        theta: [0.0, 0.02],
        vega: [0.0, 0.15],
        rho: [0.0, -0.02],
      )

      expect(outputs.probability_of_profit_target).to eq(0.0)
      expect(outputs.profit_target_ranges).to eq([])
      expect(outputs.probability_of_loss_limit).to eq(0.0)
      expect(outputs.loss_limit_ranges).to eq([])
    end

    it 'generates string representation correctly' do
      outputs = described_class.new(
        inputs: OptionLab::Models::Inputs.new(TestHelpers.covered_call_fixture),
        data: OptionLab::Models::EngineDataResults.new,
        probability_of_profit: 0.75,
        profit_ranges: [[100.0, 200.0]],
        expected_profit: 500.0,
        expected_loss: -200.0,
        per_leg_cost: [100.0, 200.0],
        strategy_cost: 300.0,
        minimum_return_in_the_domain: -500.0,
        maximum_return_in_the_domain: 1000.0,
        implied_volatility: [0.0, 0.2],
        in_the_money_probability: [1.0, 0.3],
        delta: [1.0, -0.3],
        gamma: [0.0, 0.01],
        theta: [0.0, 0.02],
        vega: [0.0, 0.15],
        rho: [0.0, -0.02],
      )

      str_representation = outputs.to_s
      expect(str_representation).to include('Probability of profit: 0.75')
      expect(str_representation).to include('Expected profit: 500.0')
      expect(str_representation).to include('Strategy cost: 300.0')
      expect(str_representation).not_to include('data:')
      expect(str_representation).not_to include('inputs:')
    end
  end

  describe OptionLab::Models::PoPOutputs do
    it 'initializes with valid attributes' do
      pop_outputs = described_class.new(
        probability_of_reaching_target: 0.65,
        probability_of_missing_target: 0.35,
        reaching_target_range: [[100.0, 200.0]],
        missing_target_range: [[0.0, 100.0], [200.0, 300.0]],
        expected_return_above_target: 150.0,
        expected_return_below_target: -100.0,
      )

      expect(pop_outputs.probability_of_reaching_target).to eq(0.65)
      expect(pop_outputs.probability_of_missing_target).to eq(0.35)
      expect(pop_outputs.reaching_target_range).to eq([[100.0, 200.0]])
      expect(pop_outputs.missing_target_range).to eq([[0.0, 100.0], [200.0, 300.0]])
      expect(pop_outputs.expected_return_above_target).to eq(150.0)
      expect(pop_outputs.expected_return_below_target).to eq(-100.0)
    end

    it 'sets default values' do
      pop_outputs = described_class.new

      expect(pop_outputs.probability_of_reaching_target).to eq(0.0)
      expect(pop_outputs.probability_of_missing_target).to eq(0.0)
      expect(pop_outputs.reaching_target_range).to eq([])
      expect(pop_outputs.missing_target_range).to eq([])
      expect(pop_outputs.expected_return_above_target).to be_nil
      expect(pop_outputs.expected_return_below_target).to be_nil
    end
  end

  describe OptionLab::Models::BlackScholesModelInputs do
    it 'initializes with valid attributes' do
      inputs = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
        interest_rate: 0.05,
        dividend_yield: 0.01,
      )

      expect(inputs.stock_price).to eq(100.0)
      expect(inputs.volatility).to eq(0.2)
      expect(inputs.years_to_target_date).to eq(0.25)
      expect(inputs.interest_rate).to eq(0.05)
      expect(inputs.dividend_yield).to eq(0.01)
      expect(inputs.model).to eq('black-scholes')
    end

    it 'sets default values' do
      inputs = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
      )

      expect(inputs.interest_rate).to eq(0.0)
      expect(inputs.dividend_yield).to eq(0.0)
      expect(inputs.model).to eq('black-scholes')
    end

    it 'raises error when model is invalid' do
      expect do
        described_class.new(
          model: 'invalid',
          stock_price: 100.0,
          volatility: 0.2,
          years_to_target_date: 0.25,
        )
      end.to raise_error(ArgumentError, "model must be 'black-scholes' or 'normal'")
    end

    it 'implements hash and eql? correctly' do
      inputs1 = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
        interest_rate: 0.05,
        dividend_yield: 0.01,
      )

      inputs2 = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
        interest_rate: 0.05,
        dividend_yield: 0.01,
      )

      inputs3 = described_class.new(
        stock_price: 200.0,
        volatility: 0.3,
        years_to_target_date: 0.5,
        interest_rate: 0.06,
        dividend_yield: 0.02,
      )

      expect(inputs1.hash).to eq(inputs2.hash)
      expect(inputs1.hash).not_to eq(inputs3.hash)
      expect(inputs1).to eql(inputs2)
      expect(inputs1).not_to eql(inputs3)
    end
  end

  describe OptionLab::Models::LaplaceInputs do
    it 'initializes with valid attributes' do
      inputs = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
        mu: 0.05,
      )

      expect(inputs.stock_price).to eq(100.0)
      expect(inputs.volatility).to eq(0.2)
      expect(inputs.years_to_target_date).to eq(0.25)
      expect(inputs.mu).to eq(0.05)
      expect(inputs.model).to eq('laplace')
    end

    it 'raises error when model is invalid' do
      expect do
        described_class.new(
          model: 'invalid',
          stock_price: 100.0,
          volatility: 0.2,
          years_to_target_date: 0.25,
          mu: 0.05,
        )
      end.to raise_error(ArgumentError, "model must be 'laplace'")
    end

    it 'implements hash and eql? correctly' do
      inputs1 = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
        mu: 0.05,
      )

      inputs2 = described_class.new(
        stock_price: 100.0,
        volatility: 0.2,
        years_to_target_date: 0.25,
        mu: 0.05,
      )

      inputs3 = described_class.new(
        stock_price: 200.0,
        volatility: 0.3,
        years_to_target_date: 0.5,
        mu: 0.06,
      )

      expect(inputs1.hash).to eq(inputs2.hash)
      expect(inputs1.hash).not_to eq(inputs3.hash)
      expect(inputs1).to eql(inputs2)
      expect(inputs1).not_to eql(inputs3)
    end
  end

  describe OptionLab::Models::ArrayInputs do
    it 'initializes with valid attributes' do
      inputs = described_class.new(
        array: [100.0, 110.0, 120.0, 130.0, 140.0],
      )

      expect(inputs.array).to be_a(Numo::DFloat)
      expect(inputs.array.size).to eq(5)
      expect(inputs.model).to eq('array')
    end

    it 'converts array to Numo::DFloat' do
      inputs = described_class.new(
        array: [100.0, 110.0, 120.0, 130.0, 140.0],
      )

      expect(inputs.array).to be_a(Numo::DFloat)
      expect(inputs.array[0]).to eq(100.0)
      expect(inputs.array[-1]).to eq(140.0)
    end

    it 'raises error when model is invalid' do
      expect do
        described_class.new(
          model: 'invalid',
          array: [100.0, 110.0, 120.0, 130.0, 140.0],
        )
      end.to raise_error(ArgumentError, "model must be 'array'")
    end

    it 'raises error when array is empty' do
      expect do
        described_class.new(
          array: [],
        )
      end.to raise_error(ArgumentError, 'The array is empty!')
    end
  end
end