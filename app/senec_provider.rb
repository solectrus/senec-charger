require 'senec'

class SenecProvider
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def bat_fuel_charge
    request.get('ENERGY', 'GUI_BAT_DATA_FUEL_CHARGE')
  end

  def bat_empty?
    bat_fuel_charge.zero?
  end

  def safe_charge_running?
    request.get('ENERGY', 'SAFE_CHARGE_RUNNING') == 1
  end

  def bat_fuel_charge_increased?
    @former_bat_fuel_charge && @former_bat_fuel_charge < bat_fuel_charge
  end

  def start_charge!
    # Logic for starting safe charging
  end

  def allow_discharge!
    # Logic for allowing discharging
  end

  private

  def request
    return @request if fresh?

    @former_bat_fuel_charge = bat_fuel_charge if @request
    @last_request_at = Time.now

    @request =
      Senec::Local::Request.new connection: config.senec_connection,
                                body: {
                                  ENERGY: {
                                    GUI_BAT_DATA_FUEL_CHARGE: '',
                                    SAFE_CHARGE_RUNNING: '',
                                  },
                                }
  end

  # Is the last request less than 5 seconds ago?
  def fresh?
    @request && @last_request_at && @last_request_at > Time.now - 5
  end
end
