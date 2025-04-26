# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OptionLab::BlackScholes do
  let(:stock_price) { 100.0 }
  let(:strike) { 105.0 }
  let(:interest_rate) { 0.01 }
  let(:dividend_yield) { 0.0 }
  let(:volatility) { 0.20 }
  let(:days_to_maturity) { 60 }
  let(:years_to_maturity) { days_to_maturity / 365.0 }

  describe '.get_d1' do
    it 'calculates d1 correctly' do
      d1 = described_class.get_d1(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)
      expect(d1).to be_within(0.001).of(-0.180)
    end
  end

  describe '.get_d2' do
    it 'calculates d2 correctly' do
      d2 = described_class.get_d2(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)
      expect(d2).to be_within(0.001).of(-0.231)
    end
  end

  describe '.get_option_price' do
    it 'calculates call price correctly' do
      d1 = described_class.get_d1(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)
      d2 = described_class.get_d2(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)

      call_price = described_class.get_option_price('call', stock_price, strike, interest_rate, years_to_maturity, d1, d2, dividend_yield)
      expect(call_price).to be_within(0.01).of(2.70)
    end

    it 'calculates put price correctly' do
      d1 = described_class.get_d1(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)
      d2 = described_class.get_d2(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)

      put_price = described_class.get_option_price('put', stock_price, strike, interest_rate, years_to_maturity, d1, d2, dividend_yield)
      expect(put_price).to be_within(0.01).of(7.15)
    end

    it 'raises error for invalid option type' do
      d1 = described_class.get_d1(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)
      d2 = described_class.get_d2(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield)

      expect do
        described_class.get_option_price('invalid', stock_price, strike, interest_rate, years_to_maturity, d1, d2, dividend_yield)
      end.to raise_error(ArgumentError, "Option type must be either 'call' or 'put'!")
    end
  end

  describe '.get_bs_info' do
    let(:bs_info) { described_class.get_bs_info(stock_price, strike, interest_rate, volatility, years_to_maturity, dividend_yield) }

    it 'calculates call price correctly' do
      expect(bs_info.call_price).to be_within(0.01).of(2.70)
    end

    it 'calculates put price correctly' do
      expect(bs_info.put_price).to be_within(0.01).of(7.15)
    end

    it 'calculates call delta correctly' do
      expect(bs_info.call_delta).to be_within(0.001).of(0.428)
    end

    it 'calculates put delta correctly' do
      expect(bs_info.put_delta).to be_within(0.001).of(-0.572)
    end

    it 'calculates gamma correctly' do
      expect(bs_info.gamma).to be_within(0.001).of(0.027)
    end

    it 'calculates vega correctly' do
      expect(bs_info.vega).to be_within(0.01).of(0.11)
    end

    it 'calculates call rho correctly' do
      expect(bs_info.call_rho).to be_within(0.01).of(0.02)
    end

    it 'calculates put rho correctly' do
      expect(bs_info.put_rho).to be_within(0.01).of(-0.04)
    end

    it 'calculates call ITM probability correctly' do
      expect(bs_info.call_itm_prob).to be_within(0.001).of(0.409)
    end

    it 'calculates put ITM probability correctly' do
      expect(bs_info.put_itm_prob).to be_within(0.001).of(0.591)
    end
  end

  describe '.get_implied_vol' do
    it 'calculates implied volatility for a call option' do
      call_price = 2.70
      implied_vol = described_class.get_implied_vol('call', call_price, stock_price, strike, interest_rate, years_to_maturity, dividend_yield)
      expect(implied_vol).to be_within(0.01).of(0.20)
    end

    it 'calculates implied volatility for a put option' do
      put_price = 7.15
      implied_vol = described_class.get_implied_vol('put', put_price, stock_price, strike, interest_rate, years_to_maturity, dividend_yield)
      expect(implied_vol).to be_within(0.01).of(0.20)
    end
  end
end
