# frozen_string_literal: true

module OptionLab
  # Configuration class for OptionLab
  # Controls validation and behavior throughout the library
  class Configuration
    attr_accessor :skip_strategy_validation,
      :check_closed_positions_only,
      :check_expiration_dates_only,
      :check_date_target_mixing_only,
      :check_dates_or_days_only,
      :check_array_model_only

    def initialize
      @skip_strategy_validation = false
      @check_closed_positions_only = false
      @check_expiration_dates_only = false
      @check_date_target_mixing_only = false
      @check_dates_or_days_only = false
      @check_array_model_only = false
    end
  end

  # Module-level configuration
  @configuration = Configuration.new

  class << self
    # Get the current configuration
    # @return [Configuration] the current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the library
    # @yield [config] Configuration object that can be modified
    def configure
      yield configuration if block_given?
    end

    # Reset configuration to defaults
    def reset_configuration
      @configuration = Configuration.new
    end
  end
end