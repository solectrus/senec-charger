require 'forwardable'

class BatteryAction
  extend Forwardable

  def initialize(senec:, prices:, forecast:)
    @senec = senec
    @prices = prices
    @forecast = forecast
  end

  attr_reader :senec, :prices, :forecast

  def_delegators :senec,
                 :safe_charge_running?,
                 :bat_fuel_charge,
                 :bat_empty?,
                 :bat_fuel_charge_increased?
  def_delegators :prices, :cheap_grid_power?
  def_delegators :forecast, :sunshine_ahead?

  def perform!(count: 1) # rubocop:disable Metrics/PerceivedComplexity
    puts "##{count} - #{Time.now}"

    if safe_charge_running?
      info 'Battery is safe charging'

      if bat_fuel_charge_increased?
        noop "Still charging (#{bat_fuel_charge} %)"
      else
        info 'Battery fuel charge not increased'
        allow_discharge!
      end

      return
    end

    if bat_empty?
      info 'Battery is empty'

      if sunshine_ahead?
        noop 'Sunshine ahead'
      else
        info 'No sunshine ahead'

        if cheap_grid_power?
          info 'Grid power is cheap'
          start_charge!
        else
          noop 'Grid power expensive'
        end
      end
    else
      noop "Battery not empty (#{bat_fuel_charge} %)"
    end
  end

  private

  def start_charge!
    puts '- Start charge!'
    senec.start_charge!
  end

  def allow_discharge!
    puts '- Allow discharge!'
    senec.allow_discharge!
  end

  def info(message)
    print "#{message} | "
  end

  def noop(message)
    puts "#{message} - nothing to do"
  end
end
