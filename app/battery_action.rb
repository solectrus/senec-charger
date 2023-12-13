require 'forwardable'

class BatteryAction
  extend Forwardable

  def initialize(senec:, prices:, forecast:)
    @senec = senec
    @prices = prices
    @forecast = forecast
  end

  def perform!
    result = determine_result

    case result
    when :start_charge
      senec.start_charge!
    when :allow_discharge
      senec.allow_discharge!
    end

    result
  end

  private

  attr_reader :senec, :prices, :forecast

  def_delegators :senec,
                 :safe_charge_running?,
                 :bat_fuel_charge,
                 :bat_empty?,
                 :bat_fuel_charge_increased?
  def_delegators :prices, :cheap_grid_power?
  def_delegators :forecast, :sunshine_ahead?

  def determine_result
    if safe_charge_running?
      bat_fuel_charge_increased? ? :still_charging : :allow_discharge
    elsif bat_empty?
      if sunshine_ahead?
        :sunshine_ahead
      else
        cheap_grid_power? ? :start_charge : :grid_power_not_cheap
      end
    else
      :not_empty
    end
  end
end
