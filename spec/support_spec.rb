# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OptionLab::Support do
  describe '.get_pl_profile' do
    let(:stock_prices) { Numo::DFloat.new(5).seq(100, 10) } # [100, 110, 120, 130, 140]

    context 'with call option' do
      it 'calculates P/L profile for long call correctly' do
        strike = 115.0
        premium = 5.0
        contracts = 1

        profile, cost = described_class.get_pl_profile('call', 'buy', strike, premium, contracts, stock_prices)

        # Cost should be negative (money paid)
        expect(cost).to eq(-5.0)

        # Expected P/L at each price point
        # At 100: Out of the money, lose premium
        expect(profile[0]).to eq(-5.0)

        # At 110: Out of the money, lose premium
        expect(profile[1]).to eq(-5.0)

        # At 120: In the money by 5, but still lose 5 - 5 = 0
        expect(profile[2]).to be_within(0.01).of(0.0)

        # At 130: In the money by 15, profit 15 - 5 = 10
        expect(profile[3]).to be_within(0.01).of(10.0)
      end

      it 'calculates P/L profile for short call correctly' do
        strike = 115.0
        premium = 5.0
        contracts = 1

        profile, cost = described_class.get_pl_profile('call', 'sell', strike, premium, contracts, stock_prices)

        # Cost should be positive (money received)
        expect(cost).to eq(5.0)

        # Expected P/L at each price point
        # At 100: Out of the money, keep premium
        expect(profile[0]).to eq(5.0)

        # At 110: Out of the money, keep premium
        expect(profile[1]).to eq(5.0)

        # At 120: In the money by 5, premium minus loss: 5 - 5 = 0
        expect(profile[2]).to be_within(0.01).of(0.0)

        # At 130: In the money by 15, premium minus loss: 5 - 15 = -10
        expect(profile[3]).to be_within(0.01).of(-10.0)
      end

      it 'handles multiple contracts correctly' do
        strike = 115.0
        premium = 5.0
        contracts = 10

        profile, cost = described_class.get_pl_profile('call', 'buy', strike, premium, contracts, stock_prices)

        # Cost should be negative (money paid) * contracts
        expect(cost).to eq(-50.0)

        # At 130: In the money by 15, profit (15 - 5) * 10 = 100
        expect(profile[3]).to be_within(0.01).of(100.0)
      end

      it 'handles commission correctly' do
        strike = 115.0
        premium = 5.0
        contracts = 1
        commission = 1.0

        profile, cost = described_class.get_pl_profile('call', 'buy', strike, premium, contracts, stock_prices, commission)

        # Cost should include commission
        expect(cost).to eq(-6.0)

        # P/L should include commission
        expect(profile[3]).to be_within(0.01).of(9.0) # 10 - 1
      end
    end

    context 'with put option' do
      it 'calculates P/L profile for long put correctly' do
        strike = 115.0
        premium = 5.0
        contracts = 1

        profile, cost = described_class.get_pl_profile('put', 'buy', strike, premium, contracts, stock_prices)

        # Cost should be negative (money paid)
        expect(cost).to eq(-5.0)

        # Expected P/L at each price point
        # At 100: In the money by 15, profit 15 - 5 = 10
        expect(profile[0]).to be_within(0.01).of(10.0)

        # At 110: In the money by 5, profit 5 - 5 = 0
        expect(profile[1]).to be_within(0.01).of(0.0)

        # At 120: Out of the money, lose premium
        expect(profile[2]).to eq(-5.0)
      end

      it 'calculates P/L profile for short put correctly' do
        strike = 115.0
        premium = 5.0
        contracts = 1

        profile, cost = described_class.get_pl_profile('put', 'sell', strike, premium, contracts, stock_prices)

        # Cost should be positive (money received)
        expect(cost).to eq(5.0)

        # Expected P/L at each price point
        # At 100: In the money by 15, premium minus loss: 5 - 15 = -10
        expect(profile[0]).to be_within(0.01).of(-10.0)

        # At 110: In the money by 5, premium minus loss: 5 - 5 = 0
        expect(profile[1]).to be_within(0.01).of(0.0)

        # At 120: Out of the money, keep premium
        expect(profile[2]).to eq(5.0)
      end
    end

    it 'raises error for invalid option type' do
      expect do
        described_class.get_pl_profile('invalid', 'buy', 100.0, 5.0, 1, stock_prices)
      end.to raise_error(ArgumentError, "Option type must be either 'call' or 'put'!")
    end

    it 'raises error for invalid action' do
      expect do
        described_class.get_pl_profile('call', 'invalid', 100.0, 5.0, 1, stock_prices)
      end.to raise_error(ArgumentError, "Action must be either 'buy' or 'sell'!")
    end
  end

  describe '.get_pl_profile_stock' do
    let(:stock_prices) { Numo::DFloat.new(5).seq(100, 10) } # [100, 110, 120, 130, 140]

    it 'calculates P/L profile for long stock correctly' do
      stock_price = 100.0
      shares = 10

      profile, cost = described_class.get_pl_profile_stock(stock_price, 'buy', shares, stock_prices)

      # Cost should be negative (money paid) * shares
      expect(cost).to eq(-1000.0)

      # Expected P/L at each price point
      # At 100: No gain or loss
      expect(profile[0]).to eq(0.0)

      # At 110: Gain of 10 * 10 = 100
      expect(profile[1]).to eq(100.0)

      # At 140: Gain of 40 * 10 = 400
      expect(profile[4]).to eq(400.0)
    end

    it 'calculates P/L profile for short stock correctly' do
      stock_price = 100.0
      shares = 10

      profile, cost = described_class.get_pl_profile_stock(stock_price, 'sell', shares, stock_prices)

      # Cost should be positive (money received) * shares
      expect(cost).to eq(1000.0)

      # Expected P/L at each price point
      # At 100: No gain or loss
      expect(profile[0]).to eq(0.0)

      # At 110: Loss of 10 * 10 = -100
      expect(profile[1]).to eq(-100.0)

      # At 140: Loss of 40 * 10 = -400
      expect(profile[4]).to eq(-400.0)
    end
  end
end
