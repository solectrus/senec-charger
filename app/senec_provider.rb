require 'senec'

class SenecProvider
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  STAT_STATE_EMPTY = 15

  def bat_fuel_charge
    refresh_request
    @bat_fuel_charge
  end

  def stat_state
    refresh_request
    @stat_state
  end

  def bat_empty?
    stat_state == STAT_STATE_EMPTY
  end

  def safe_charge_running?
    refresh_request
    @safe_charge_running
  end

  def bat_fuel_charge_increased?
    # If we don't have a former value, we assume the charge has increased
    return true unless @former_bat_fuel_charge

    @former_bat_fuel_charge < bat_fuel_charge
  end

  def start_charge!
    return if config.charger_dry_run

    Senec::Local::Request.new(
      connection: config.senec_connection,
      body: Senec::Local::SAFETY_CHARGE,
    ).perform!
  end

  def allow_discharge!
    return if config.charger_dry_run

    Senec::Local::Request.new(
      connection: config.senec_connection,
      body: Senec::Local::ALLOW_DISCHARGE,
    ).perform!
  end

  private

  def refresh_request
    return if request_still_valid?

    remember_request
    request = create_new_data_request
    @bat_fuel_charge =
      request.get('ENERGY', 'GUI_BAT_DATA_FUEL_CHARGE').round(1)
    @stat_state = request.get('ENERGY', 'STAT_STATE')
    @safe_charge_running = request.get('ENERGY', 'SAFE_CHARGE_RUNNING') == 1
  end

  def request_still_valid?
    # Cache for 1 minute
    @last_request_at && @last_request_at > Time.now - 60
  end

  def remember_request
    @former_bat_fuel_charge = @bat_fuel_charge
    @last_request_at = Time.now
  end

  def create_new_data_request
    Senec::Local::Request.new(
      connection: config.senec_connection,
      body: {
        ENERGY: {
          GUI_BAT_DATA_FUEL_CHARGE: '',
          STAT_STATE: '',
          SAFE_CHARGE_RUNNING: '',
        },
      },
    )
  end
end
