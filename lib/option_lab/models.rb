# frozen_string_literal: true

require 'date'
require 'numo/narray'

module OptionLab
  module Models
    # Constants and types
    OPTION_TYPES = %w[call put].freeze
    ACTIONS = %w[buy sell].freeze
    STRATEGY_TYPES = (OPTION_TYPES + %w[stock closed]).freeze
    THEORETICAL_MODELS = %w[black-scholes normal array].freeze

    class << self
      # Helper to create an empty array
      def init_empty_array
        Numo::DFloat.new(0)
      end
    end

    # Base class for all models
    class BaseModel
      def initialize(attributes = {})
        attributes.each do |key, value|
          instance_variable_set("@#{key}", value) if respond_to?("#{key}=")
        end
        validate!
      end

      def validate!
        # Override in subclasses
      end

      def to_h
        instance_variables.each_with_object({}) do |var, hash|
          hash[var.to_s.delete('@').to_sym] = instance_variable_get(var)
        end
      end
    end

    # Base class for strategy legs
    class BaseLeg < BaseModel
      attr_accessor :n, :action, :prev_pos

      def validate!
        raise ArgumentError, "n must be positive" unless n.is_a?(Integer) && n.positive?
        raise ArgumentError, "action must be 'buy' or 'sell'" unless ACTIONS.include?(action)
      end
    end

    # Stock leg in a strategy
    class Stock < BaseLeg
      attr_accessor :type
      
      def initialize(attributes = {})
        @type = "stock"
        super(attributes)
      end
    end

    # Option leg in a strategy
    class Option < BaseLeg
      attr_accessor :type, :strike, :premium, :expiration
      
      def validate!
        super
        raise ArgumentError, "type must be 'call' or 'put'" unless OPTION_TYPES.include?(type)
        raise ArgumentError, "strike must be positive" unless strike.is_a?(Numeric) && strike.positive?
        raise ArgumentError, "premium must be positive" unless premium.is_a?(Numeric) && premium.positive?
        
        if expiration
          if expiration.is_a?(Integer) && expiration <= 0
            raise ArgumentError, "If expiration is an integer, it must be greater than 0"
          elsif !expiration.is_a?(Date) && !expiration.is_a?(Integer)
            raise ArgumentError, "expiration must be a Date, an Integer, or nil"
          end
        end
      end
    end

    # Previously closed position in a strategy
    class ClosedPosition < BaseModel
      attr_accessor :type, :prev_pos
      
      def initialize(attributes = {})
        @type = "closed"
        super(attributes)
      end
      
      def validate!
        raise ArgumentError, "prev_pos must be a number" unless prev_pos.is_a?(Numeric)
      end
    end

    # Theoretical model inputs
    class TheoreticalModelInputs < BaseModel
      attr_accessor :stock_price, :volatility, :years_to_target_date
      
      def validate!
        raise ArgumentError, "stock_price must be positive" unless stock_price.is_a?(Numeric) && stock_price.positive?
        raise ArgumentError, "volatility must be positive" unless volatility.is_a?(Numeric) && volatility.positive?
        raise ArgumentError, "years_to_target_date must be non-negative" unless years_to_target_date.is_a?(Numeric) && years_to_target_date >= 0
      end
    end

    # Black-Scholes model inputs
    class BlackScholesModelInputs < TheoreticalModelInputs
      attr_accessor :model, :interest_rate, :dividend_yield
      
      def initialize(attributes = {})
        @model = "black-scholes"
        @interest_rate = 0.0
        @dividend_yield = 0.0
        super(attributes)
      end
      
      def validate!
        super
        raise ArgumentError, "model must be 'black-scholes' or 'normal'" unless %w[black-scholes normal].include?(model)
        raise ArgumentError, "interest_rate must be non-negative" unless interest_rate.is_a?(Numeric) && interest_rate >= 0
        raise ArgumentError, "dividend_yield must be between 0 and 1" unless dividend_yield.is_a?(Numeric) && dividend_yield >= 0 && dividend_yield <= 1
      end

      def hash
        [model, stock_price, volatility, years_to_target_date, interest_rate, dividend_yield].hash
      end

      def eql?(other)
        hash == other.hash
      end
    end

    # Laplace model inputs
    class LaplaceInputs < TheoreticalModelInputs
      attr_accessor :model, :mu
      
      def initialize(attributes = {})
        @model = "laplace"
        super(attributes)
      end
      
      def validate!
        super
        raise ArgumentError, "model must be 'laplace'" unless model == "laplace"
        raise ArgumentError, "mu must be a number" unless mu.is_a?(Numeric)
      end

      def hash
        [model, stock_price, volatility, years_to_target_date, mu].hash
      end

      def eql?(other)
        hash == other.hash
      end
    end

    # Array model inputs
    class ArrayInputs < BaseModel
      attr_accessor :model, :array
      
      def initialize(attributes = {})
        @model = "array"
        super(attributes)
      end
      
      def validate!
        raise ArgumentError, "model must be 'array'" unless model == "array"
        
        if array.nil? || (array.respond_to?(:size) && array.size == 0)
          raise ArgumentError, "The array is empty!"
        end
        
        # Convert array to Numo::DFloat if it's not already
        @array = Numo::DFloat.cast(array) unless array.is_a?(Numo::DFloat)
      end
    end

    # Main input model for a strategy calculation
    class Inputs < BaseModel
      attr_accessor :stock_price, :volatility, :interest_rate, :min_stock, :max_stock,
                    :strategy, :dividend_yield, :profit_target, :loss_limit,
                    :opt_commission, :stock_commission, :discard_nonbusiness_days,
                    :business_days_in_year, :country, :start_date, :target_date,
                    :days_to_target_date, :model, :array

      def initialize(attributes = {})
        # Set defaults
        @dividend_yield = 0.0
        @opt_commission = 0.0
        @stock_commission = 0.0
        @discard_nonbusiness_days = true
        @business_days_in_year = 252
        @country = "US"
        @days_to_target_date = 0
        @model = "black-scholes"
        @array = init_empty_array
        
        # Process attributes
        super(attributes)
        
        # Convert hash strategy to objects if needed
        if @strategy.is_a?(Array) && @strategy.first.is_a?(Hash)
          @strategy = @strategy.map do |leg|
            case leg[:type]
            when "stock" then Stock.new(leg)
            when "call", "put" then Option.new(leg)
            when "closed" then ClosedPosition.new(leg)
            else
              raise ArgumentError, "Invalid strategy leg type: #{leg[:type]}"
            end
          end
        end
      end

      def validate!
        # Base validations
        raise ArgumentError, "stock_price must be positive" unless stock_price.is_a?(Numeric) && stock_price.positive?
        raise ArgumentError, "volatility must be non-negative" unless volatility.is_a?(Numeric) && volatility >= 0
        raise ArgumentError, "interest_rate must be non-negative" unless interest_rate.is_a?(Numeric) && interest_rate >= 0
        raise ArgumentError, "min_stock must be non-negative" unless min_stock.is_a?(Numeric) && min_stock >= 0
        raise ArgumentError, "max_stock must be non-negative" unless max_stock.is_a?(Numeric) && max_stock >= 0
        raise ArgumentError, "strategy must not be empty" unless strategy.is_a?(Array) && strategy.size >= 1
        
        # Validate strategy
        validate_strategy!
        
        # Validate dates
        validate_dates!
        
        # Validate model and array
        validate_model_array!
      end

      private

      def init_empty_array
        Models.init_empty_array
      end

      def validate_strategy!
        types = strategy.map { |s| s.respond_to?(:type) ? s.type : s[:type] }
        if types.count("closed") > 1
          raise ArgumentError, "Only one position of type 'closed' is allowed!"
        end
      end

      def validate_dates!
        expiration_dates = strategy.select { |s| s.is_a?(Option) && s.expiration.is_a?(Date) }
                                   .map(&:expiration)
        
        if start_date && target_date
          if expiration_dates.any? { |date| date < target_date }
            raise ArgumentError, "Expiration dates must be after or on target date!"
          end
          
          if start_date >= target_date
            raise ArgumentError, "Start date must be before target date!"
          end
          
          return
        end
        
        if days_to_target_date && days_to_target_date > 0
          if expiration_dates.any?
            raise ArgumentError, "You can't mix a strategy expiration with a days_to_target_date."
          end
          
          return
        end
        
        raise ArgumentError, "Either start_date and target_date or days_to_maturity must be provided"
      end

      def validate_model_array!
        return unless model == "array"
        
        if array.nil? || array.size == 0
          raise ArgumentError, "Array of terminal stock prices must be provided if model is 'array'."
        end
      end
    end

    # Black-Scholes calculation results
    class BlackScholesInfo < BaseModel
      attr_accessor :call_price, :put_price, :call_delta, :put_delta, :call_theta,
                    :put_theta, :gamma, :vega, :call_rho, :put_rho, :call_itm_prob,
                    :put_itm_prob
    end

    # Engine data results
    class EngineDataResults < BaseModel
      attr_accessor :stock_price_array, :terminal_stock_prices, :profit,
                    :profit_mc, :strategy_profit, :strategy_profit_mc, 
                    :strike, :premium, :n, :action, :type
      
      def initialize(attributes = {})
        @terminal_stock_prices = init_empty_array
        @profit = init_empty_array
        @profit_mc = init_empty_array
        @strategy_profit = init_empty_array
        @strategy_profit_mc = init_empty_array
        @strike = []
        @premium = []
        @n = []
        @action = []
        @type = []
        
        super(attributes)
      end
      
      private
      
      def init_empty_array
        Models.init_empty_array
      end
    end

    # Engine data
    class EngineData < EngineDataResults
      attr_accessor :inputs, :previous_position, :use_bs, :profit_ranges,
                    :profit_target_ranges, :loss_limit_ranges, :days_to_maturity,
                    :days_in_year, :days_to_target, :implied_volatility,
                    :itm_probability, :delta, :gamma, :vega, :rho, :theta, :cost,
                    :profit_probability, :profit_target_probability,
                    :loss_limit_probability, :expected_profit, :expected_loss
      
      def initialize(attributes = {})
        @previous_position = []
        @use_bs = []
        @profit_ranges = []
        @profit_target_ranges = []
        @loss_limit_ranges = []
        @days_to_maturity = []
        @days_in_year = 365
        @days_to_target = 30
        @implied_volatility = []
        @itm_probability = []
        @delta = []
        @gamma = []
        @vega = []
        @rho = []
        @theta = []
        @cost = []
        @profit_probability = 0.0
        @profit_target_probability = 0.0
        @loss_limit_probability = 0.0
        @expected_profit = nil
        @expected_loss = nil
        
        super(attributes)
      end
    end

    # Strategy calculation outputs
    class Outputs < BaseModel
      attr_accessor :inputs, :data, :probability_of_profit, :profit_ranges,
                    :expected_profit, :expected_loss, :per_leg_cost, :strategy_cost,
                    :minimum_return_in_the_domain, :maximum_return_in_the_domain,
                    :implied_volatility, :in_the_money_probability, :delta, :gamma,
                    :theta, :vega, :rho, :probability_of_profit_target,
                    :profit_target_ranges, :probability_of_loss_limit,
                    :loss_limit_ranges
      
      def initialize(attributes = {})
        @probability_of_profit_target = 0.0
        @profit_target_ranges = []
        @probability_of_loss_limit = 0.0
        @loss_limit_ranges = []
        
        super(attributes)
      end
      
      def to_s
        result = ""
        
        # Exclude data and inputs
        exclude = [:data, :inputs]
        
        to_h.each do |key, value|
          next if exclude.include?(key) || value.nil? || 
                 (value.respond_to?(:empty?) && value.empty?)
          
          # Format the key by capitalizing and replacing underscores with spaces
          formatted_key = key.to_s.capitalize.gsub('_', ' ')
          result += "#{formatted_key}: #{value}\n"
        end
        
        result
      end
    end

    # Probability of profit calculation outputs
    class PoPOutputs < BaseModel
      attr_accessor :probability_of_reaching_target, :probability_of_missing_target,
                    :reaching_target_range, :missing_target_range,
                    :expected_return_above_target, :expected_return_below_target
      
      def initialize(attributes = {})
        @probability_of_reaching_target = 0.0
        @probability_of_missing_target = 0.0
        @reaching_target_range = []
        @missing_target_range = []
        @expected_return_above_target = nil
        @expected_return_below_target = nil
        
        super(attributes)
      end
    end
  end
end
