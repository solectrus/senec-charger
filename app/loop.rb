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
      battery_action.perform!(count:)

      break if max_count && count >= max_count

      puts "Sleeping for #{config.senec_interval} seconds ..."
      sleep config.senec_interval
      puts
    end
  end

  private

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
