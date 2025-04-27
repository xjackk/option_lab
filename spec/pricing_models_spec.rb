# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Option Pricing Models' do
  let(:spot_price) { 100.0 }
  let(:strike_price) { 105.0 }
  let(:risk_free_rate) { 0.05 }
  let(:volatility) { 0.25 }
  let(:years_to_maturity) { 1.0 }
  let(:dividend_yield) { 0.03 }

  describe OptionLab::BinomialTree do
    describe '.price_option' do
      context 'with European options (same as Black-Scholes)' do
        it 'prices a European call option correctly' do
          # Price using Binomial Tree with European option
          binomial_price = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            800,
            false,
            dividend_yield,
          )

          # Price using Black-Scholes for comparison
          bs_price = OptionLab::BlackScholes.get_bs_info(
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          ).call_price

          # They should match closely with enough steps
          expect(binomial_price).to be_within(0.01).of(bs_price)
        end

        it 'prices a European put option correctly' do
          # Price using Binomial Tree with European option
          binomial_price = described_class.price_option(
            'put',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            800,
            false,
            dividend_yield,
          )

          # Price using Black-Scholes for comparison
          bs_price = OptionLab::BlackScholes.get_bs_info(
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          ).put_price

          # They should match closely with enough steps
          expect(binomial_price).to be_within(0.01).of(bs_price)
        end
      end

      context 'with American options' do
        it 'prices an American call option correctly' do
          # For non-dividend paying stocks, American call = European call
          no_div_binomial = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            100,
            true,
            0.0,
          )

          no_div_european = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            100,
            false,
            0.0,
          )

          # They should be the same
          expect(no_div_binomial).to be_within(0.0001).of(no_div_european)

          # With dividends, American call may be > European call
          am_call = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            100,
            true,
            dividend_yield,
          )

          eu_call = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            100,
            false,
            dividend_yield,
          )

          # American should be greater than or equal
          expect(am_call).to be >= eu_call
        end

        it 'prices an American put option correctly' do
          # American put should always be >= European put
          am_put = described_class.price_option(
            'put',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            100,
            true,
            dividend_yield,
          )

          eu_put = described_class.price_option(
            'put',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            100,
            false,
            dividend_yield,
          )

          # American should be greater than or equal
          expect(am_put).to be > eu_put
        end
      end
    end

    describe '.get_greeks' do
      it 'calculates reasonable values for option Greeks' do
        greeks = described_class.get_greeks(
          'call',
          spot_price,
          strike_price,
          risk_free_rate,
          volatility,
          years_to_maturity,
          100,
          true,
          dividend_yield,
        )

        # Delta should be between 0 and 1 for calls
        expect(greeks[:delta]).to be_between(0, 1)

        # Gamma should be positive
        expect(greeks[:gamma]).to be > 0

        # Vega should be positive
        expect(greeks[:vega]).to be > 0

        # Put option delta should be negative
        put_greeks = described_class.get_greeks(
          'put',
          spot_price,
          strike_price,
          risk_free_rate,
          volatility,
          years_to_maturity,
          100,
          true,
          dividend_yield,
        )

        expect(put_greeks[:delta]).to be < 0
      end
    end

    describe '.get_tree' do
      it 'returns a properly structured binomial tree' do
        tree = described_class.get_tree(
          'call',
          spot_price,
          strike_price,
          risk_free_rate,
          volatility,
          years_to_maturity,
          5,
          true,
          dividend_yield,
        )

        # Check tree structure
        expect(tree[:stock_prices].length).to eq(6) # 5 steps + initial state
        expect(tree[:option_values].length).to eq(6)
        expect(tree[:exercise_flags].length).to eq(6)

        # Each step i should have i+1 nodes
        6.times do |i|
          expect(tree[:stock_prices][i].length).to be >= i + 1
          expect(tree[:option_values][i].length).to be >= i + 1
          expect(tree[:exercise_flags][i].length).to be >= i + 1
        end

        # Initial stock price should match
        expect(tree[:stock_prices][0][0]).to eq(spot_price)

        # Check parameters
        expect(tree[:parameters][:option_type]).to eq('call')
        expect(tree[:parameters][:spot_price]).to eq(spot_price)
        expect(tree[:parameters][:strike_price]).to eq(strike_price)
        expect(tree[:parameters][:up_factor]).to be > 1
        expect(tree[:parameters][:down_factor]).to be < 1
        expect(tree[:parameters][:risk_neutral_probability]).to be_between(0, 1)
      end
    end
  end

  describe OptionLab::BjerksundStensland do
    describe '.price_option' do
      context 'with American call options' do
        it 'matches the European price for non-dividend paying stocks' do
          # For non-dividend paying stocks, American call = European call
          bs_am_call = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            0.0,
          )

          bs_eu_call = OptionLab::BlackScholes.get_bs_info(
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            0.0,
          ).call_price

          # They should be the same
          expect(bs_am_call).to be_within(0.01).of(bs_eu_call)
        end

        it 'is greater than European price for dividend paying stocks' do
          # American price should exceed European price with dividends
          bs_am_call = described_class.price_option(
            'call',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          )

          bs_eu_call = OptionLab::BlackScholes.get_bs_info(
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          ).call_price

          # American should be greater than or equal
          expect(bs_am_call).to be >= bs_eu_call
        end
      end

      context 'with American put options' do
        it 'is greater than European price' do
          # American put should always be > European put
          bs_am_put = described_class.price_option(
            'put',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          )

          bs_eu_put = OptionLab::BlackScholes.get_bs_info(
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          ).put_price

          # American should be greater
          expect(bs_am_put).to be > bs_eu_put
        end

        it 'matches CRR binomial tree pricing with many steps' do
          # Price using Bjerksund-Stensland model
          bs_am_put = described_class.price_option(
            'put',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            dividend_yield,
          )

          # Price using CRR with many steps
          crr_am_put = OptionLab::BinomialTree.price_option(
            'put',
            spot_price,
            strike_price,
            risk_free_rate,
            volatility,
            years_to_maturity,
            800,
            true,
            dividend_yield,
          )

          # They should match closely
          expect(bs_am_put).to be_within(0.15).of(crr_am_put)
        end
      end
    end

    describe '.get_greeks' do
      it 'calculates reasonable values for option Greeks' do
        greeks = described_class.get_greeks(
          'call',
          spot_price,
          strike_price,
          risk_free_rate,
          volatility,
          years_to_maturity,
          dividend_yield,
        )

        # Delta should be between 0 and 1 for calls
        expect(greeks[:delta]).to be_between(0, 1)

        # Gamma should be positive
        expect(greeks[:gamma]).to be > 0

        # Vega should be positive
        expect(greeks[:vega]).to be > 0

        # Put option delta should be negative
        put_greeks = described_class.get_greeks(
          'put',
          spot_price,
          strike_price,
          risk_free_rate,
          volatility,
          years_to_maturity,
          dividend_yield,
        )

        expect(put_greeks[:delta]).to be < 0
      end
    end
  end

  describe 'OptionLab module API methods' do
    it 'provides accessible pricing methods' do
      # Test the module API method for CRR Binomial
      binomial_price = OptionLab.price_binomial(
        'call',
        spot_price,
        strike_price,
        risk_free_rate,
        volatility,
        years_to_maturity,
        100,
        true,
        dividend_yield,
      )
      expect(binomial_price).to be > 0

      # Test the module API method for Bjerksund-Stensland
      american_price = OptionLab.price_american(
        'call',
        spot_price,
        strike_price,
        risk_free_rate,
        volatility,
        years_to_maturity,
        dividend_yield,
      )
      expect(american_price).to be > 0

      # Verify that API methods for Greeks work
      binomial_greeks = OptionLab.get_binomial_greeks(
        'call',
        spot_price,
        strike_price,
        risk_free_rate,
        volatility,
        years_to_maturity,
        100,
        true,
        dividend_yield,
      )
      expect(binomial_greeks[:delta]).to be_between(0, 1)

      american_greeks = OptionLab.get_american_greeks(
        'call',
        spot_price,
        strike_price,
        risk_free_rate,
        volatility,
        years_to_maturity,
        dividend_yield,
      )
      expect(american_greeks[:delta]).to be_between(0, 1)

      # Test the tree visualization API
      tree = OptionLab.get_binomial_tree(
        'call',
        spot_price,
        strike_price,
        risk_free_rate,
        volatility,
        years_to_maturity,
        5,
        true,
        dividend_yield,
      )
      expect(tree[:stock_prices].length).to eq(6)
    end

    it 'provides model class interfaces' do
      # Binomial model inputs
      binomial_inputs = OptionLab::Models::BinomialModelInputs.new(
        option_type: 'call',
        stock_price: spot_price,
        strike: strike_price,
        interest_rate: risk_free_rate,
        volatility: volatility,
        years_to_maturity: years_to_maturity,
        steps: 100,
        dividend_yield: dividend_yield,
      )

      binomial_price = binomial_inputs.price
      expect(binomial_price).to be > 0

      binomial_greeks = binomial_inputs.greeks
      expect(binomial_greeks[:delta]).to be_between(0, 1)

      binomial_tree = binomial_inputs.tree
      expect(binomial_tree[:stock_prices].length).to be > 0

      # American model inputs
      american_inputs = OptionLab::Models::AmericanModelInputs.new(
        option_type: 'call',
        stock_price: spot_price,
        strike: strike_price,
        interest_rate: risk_free_rate,
        volatility: volatility,
        years_to_maturity: years_to_maturity,
        dividend_yield: dividend_yield,
      )

      american_price = american_inputs.price
      expect(american_price).to be > 0

      american_greeks = american_inputs.greeks
      expect(american_greeks[:delta]).to be_between(0, 1)
    end
  end
end
