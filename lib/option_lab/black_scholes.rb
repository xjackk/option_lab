# frozen_string_literal: true

require 'numo/narray'
require 'distribution'

module OptionLab

  module BlackScholes

    class << self

      # Get d1 parameter for Black-Scholes formula
      # @param s0 [Float, Numo::DFloat] Spot price(s)
      # @param x [Float, Numo::DFloat] Strike price(s)
      # @param r [Float] Risk-free interest rate
      # @param vol [Float, Numo::DFloat] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] d1 parameter(s)
      def get_d1(s0, x, r, vol, years_to_maturity, y = 0.0)
        # Handle edge cases
        return 0.0 if years_to_maturity <= 0.0 || vol <= 0.0

        numerator = Math.log(s0 / x) + (r - y + 0.5 * vol * vol) * years_to_maturity
        denominator = vol * Math.sqrt(years_to_maturity)
        numerator / denominator
      end

      # Get d2 parameter for Black-Scholes formula
      # @param s0 [Float, Numo::DFloat] Spot price(s)
      # @param x [Float, Numo::DFloat] Strike price(s)
      # @param r [Float] Risk-free interest rate
      # @param vol [Float, Numo::DFloat] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] d2 parameter(s)
      def get_d2(s0, x, r, vol, years_to_maturity, y = 0.0)
        # Handle edge cases
        return 0.0 if years_to_maturity <= 0.0 || vol <= 0.0

        d1 = get_d1(s0, x, r, vol, years_to_maturity, y)
        d1 - vol * Math.sqrt(years_to_maturity)
      end

      # Get option price using Black-Scholes formula
      # @param option_type [String] 'call' or 'put'
      # @param s0 [Float, Numo::DFloat] Spot price(s)
      # @param x [Float, Numo::DFloat] Strike price(s)
      # @param r [Float] Risk-free interest rate
      # @param years_to_maturity [Float] Time to maturity in years
      # @param d1 [Float, Numo::DFloat] d1 parameter(s)
      # @param d2 [Float, Numo::DFloat] d2 parameter(s)
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] Option price(s)
      def get_option_price(option_type, s0, x, r, years_to_maturity, d1, d2, y = 0.0)
        # First validate option type
        unless ['call', 'put'].include?(option_type)
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end

        # Calculate normally
        s = s0 * Math.exp(-y * years_to_maturity)
        discount_factor = Math.exp(-r * years_to_maturity)

        case option_type
        when 'call'
          # Call option price: S * N(d1) - X * e^(-rT) * N(d2)
          (s * Distribution::Normal.cdf(d1)) - (x * discount_factor * Distribution::Normal.cdf(d2))
        when 'put'
          # Put option price: X * e^(-rT) * N(-d2) - S * N(-d1)
          (x * discount_factor * Distribution::Normal.cdf(-d2)) - (s * Distribution::Normal.cdf(-d1))
        end
      end

      # Get option delta
      # @param option_type [String] 'call' or 'put'
      # @param d1 [Float, Numo::DFloat] d1 parameter(s)
      # @param years_to_maturity [Float] Time to maturity in years
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] Option delta(s)
      def get_delta(option_type, d1, years_to_maturity, y = 0.0)
        yfac = Math.exp(-y * years_to_maturity)

        case option_type
        when 'call'
          yfac * Distribution::Normal.cdf(d1)
        when 'put'
          yfac * (Distribution::Normal.cdf(d1) - 1.0)
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end

      # Get option gamma
      # @param s0 [Float] Spot price
      # @param vol [Float] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param d1 [Float, Numo::DFloat] d1 parameter(s)
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] Option gamma(s)
      def get_gamma(s0, vol, years_to_maturity, d1, y = 0.0)
        yfac = Math.exp(-y * years_to_maturity)

        # PDF of d1
        cdf_d1_prime = Math.exp(-0.5 * d1 * d1) / Math.sqrt(2.0 * Math::PI)

        yfac * cdf_d1_prime / (s0 * vol * Math.sqrt(years_to_maturity))
      end

      # Get option theta
      # @param option_type [String] 'call' or 'put'
      # @param s0 [Float] Spot price
      # @param x [Float, Numo::DFloat] Strike price(s)
      # @param r [Float] Risk-free interest rate
      # @param vol [Float] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param d1 [Float, Numo::DFloat] d1 parameter(s)
      # @param d2 [Float, Numo::DFloat] d2 parameter(s)
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] Option theta(s)
      def get_theta(option_type, s0, x, r, vol, years_to_maturity, d1, d2, y = 0.0)
        s = s0 * Math.exp(-y * years_to_maturity)

        # PDF of d1
        cdf_d1_prime = Math.exp(-0.5 * d1 * d1) / Math.sqrt(2.0 * Math::PI)

        common_term = -(s * vol * cdf_d1_prime / (2.0 * Math.sqrt(years_to_maturity)))

        case option_type
        when 'call'
          common_term - (r * x * Math.exp(-r * years_to_maturity) * Distribution::Normal.cdf(d2)) + (y * s * Distribution::Normal.cdf(d1))
        when 'put'
          common_term + (r * x * Math.exp(-r * years_to_maturity) * Distribution::Normal.cdf(-d2)) - (y * s * Distribution::Normal.cdf(-d1))
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end

      # Get option vega
      # @param s0 [Float] Spot price
      # @param years_to_maturity [Float] Time to maturity in years
      # @param d1 [Float, Numo::DFloat] d1 parameter(s)
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] Option vega(s)
      def get_vega(s0, years_to_maturity, d1, y = 0.0)
        s = s0 * Math.exp(-y * years_to_maturity)

        # PDF of d1
        cdf_d1_prime = Math.exp(-0.5 * d1 * d1) / Math.sqrt(2.0 * Math::PI)

        s * cdf_d1_prime * Math.sqrt(years_to_maturity) / 100
      end

      # Get option rho
      # @param option_type [String] 'call' or 'put'
      # @param x [Float, Numo::DFloat] Strike price(s)
      # @param r [Float] Risk-free interest rate
      # @param years_to_maturity [Float] Time to maturity in years
      # @param d2 [Float, Numo::DFloat] d2 parameter(s)
      # @return [Float, Numo::DFloat] Option rho(s)
      def get_rho(option_type, x, r, years_to_maturity, d2)
        case option_type
        when 'call'
          x * years_to_maturity * Math.exp(-r * years_to_maturity) * Distribution::Normal.cdf(d2) / 100
        when 'put'
          -x * years_to_maturity * Math.exp(-r * years_to_maturity) * Distribution::Normal.cdf(-d2) / 100
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end

      # Get in-the-money probability
      # @param option_type [String] 'call' or 'put'
      # @param d2 [Float, Numo::DFloat] d2 parameter(s)
      # @param years_to_maturity [Float] Time to maturity in years
      # @param y [Float] Dividend yield
      # @return [Float, Numo::DFloat] ITM probability(ies)
      def get_itm_probability(option_type, d2, years_to_maturity, y = 0.0)
        yfac = Math.exp(-y * years_to_maturity)

        case option_type
        when 'call'
          yfac * Distribution::Normal.cdf(d2)
        when 'put'
          yfac * Distribution::Normal.cdf(-d2)
        else
          raise ArgumentError, "Option type must be either 'call' or 'put'!"
        end
      end

      # Get implied volatility
      # @param option_type [String] 'call' or 'put'
      # @param oprice [Float] Option price
      # @param s0 [Float] Spot price
      # @param x [Float] Strike price
      # @param r [Float] Risk-free interest rate
      # @param years_to_maturity [Float] Time to maturity in years
      # @param y [Float] Dividend yield
      # @return [Float] Implied volatility
      def get_implied_vol(option_type, oprice, s0, x, r, years_to_maturity, y = 0.0)
        # Start with volatilities from 0.001 to 1.0 in steps of 0.001
        volatilities = (1..1000).map { |i| i * 0.001 }

        # Calculate option prices for each volatility
        prices = volatilities.map do |vol|
          d1 = get_d1(s0, x, r, vol, years_to_maturity, y)
          d2 = get_d2(s0, x, r, vol, years_to_maturity, y)
          get_option_price(option_type, s0, x, r, years_to_maturity, d1, d2, y)
        end

        # Calculate absolute differences from market price
        diffs = prices.map { |price| (price - oprice).abs }

        # Return volatility with minimal difference
        volatilities[diffs.index(diffs.min)]
      end

      # Get all Black-Scholes info
      # @param s [Float] Spot price
      # @param x [Float, Numo::DFloat] Strike price(s)
      # @param r [Float] Risk-free interest rate
      # @param vol [Float] Volatility
      # @param years_to_maturity [Float] Time to maturity in years
      # @param y [Float] Dividend yield
      # @return [Models::BlackScholesInfo] Black-Scholes info
      def get_bs_info(s, x, r, vol, years_to_maturity, y = 0.0)
        d1 = get_d1(s, x, r, vol, years_to_maturity, y)
        d2 = get_d2(s, x, r, vol, years_to_maturity, y)

        call_price = get_option_price('call', s, x, r, years_to_maturity, d1, d2, y)
        put_price = get_option_price('put', s, x, r, years_to_maturity, d1, d2, y)
        call_delta = get_delta('call', d1, years_to_maturity, y)
        put_delta = get_delta('put', d1, years_to_maturity, y)
        call_theta = get_theta('call', s, x, r, vol, years_to_maturity, d1, d2, y)
        put_theta = get_theta('put', s, x, r, vol, years_to_maturity, d1, d2, y)
        gamma = get_gamma(s, vol, years_to_maturity, d1, y)
        vega = get_vega(s, years_to_maturity, d1, y)
        call_rho = get_rho('call', x, r, years_to_maturity, d2)
        put_rho = get_rho('put', x, r, years_to_maturity, d2)
        call_itm_prob = get_itm_probability('call', d2, years_to_maturity, y)
        put_itm_prob = get_itm_probability('put', d2, years_to_maturity, y)

        Models::BlackScholesInfo.new(
          call_price: call_price,
          put_price: put_price,
          call_delta: call_delta,
          put_delta: put_delta,
          call_theta: call_theta,
          put_theta: put_theta,
          gamma: gamma,
          vega: vega,
          call_rho: call_rho,
          put_rho: put_rho,
          call_itm_prob: call_itm_prob,
          put_itm_prob: put_itm_prob,
        )
      end

    end

  end

end
