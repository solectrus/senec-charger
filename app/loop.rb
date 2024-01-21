require 'net/http'

require_relative 'battery_action'
require_relative 'senec_provider'
require_relative 'prices_provider'
require_relative 'forecast_provider'

class Loop
  def self.start(config:, max_count: nil)
    new(config:, max_count:).start
  end

  def initialize(config:, max_count: nil)
    @config = config
    @max_count = max_count
  end

  attr_reader :config, :max_count

  def start
    self.count = 0

    loop do
      self.count += 1

      puts "##{self.count} - #{Time.now}"
      perform!

      break if max_count && count >= max_count

      puts "Sleeping for #{config.charger_interval} seconds ..."
      sleep config.charger_interval
      puts
    end
  end

  RESULT_MESSAGES = {
    start_charge: 'Start charge!',
    allow_discharge: 'Allow discharge!',
    still_charging: 'Still charging, nothing to do',
    sunshine_ahead: 'Sunshine ahead, nothing to do',
    cheap_grid_power_ahead: 'Cheap grid power ahead, waiting',
    no_cheap_grid_power_ahead: 'Grid power not cheap, nothing to do',
    not_empty: 'Battery not empty, nothing to do',
  }.freeze

  private

  def perform!
    result = battery_action.perform!
    puts RESULT_MESSAGES[result]

    case result
    when :start_charge
      log_fuel_charge
      log_forecast
      log_prices
    when :not_empty, :still_charging, :allow_discharge
      log_fuel_charge
    when :sunshine_ahead
      log_forecast
    when :no_cheap_grid_power_ahead, :cheap_grid_power_ahead
      log_prices
    end
  end

  def log_fuel_charge
    puts "  Battery charge level: #{senec.bat_fuel_charge} %"
  end

  def log_forecast
    puts "  Forecast for the next #{forecast.time_range} hours: #{forecast.total_in_kwh} kWh"
  end

  def log_prices
    puts prices
  end

  def battery_action
    @battery_action ||= BatteryAction.new(senec:, prices:, forecast:)
  end

  def senec
    @senec ||= SenecProvider.new(config:)
  end

  def prices
    @prices ||= PricesProvider.new(config:)
  end

  def forecast
    @forecast ||= ForecastProvider.new(config:)
  end

  attr_accessor :count
end
