require 'senec'

class SenecPull
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def next
    data =
      Senec::Local::Request.new connection: config.senec_connection,
                                body: {
                                  ENERGY: {
                                    GUI_BAT_DATA_FUEL_CHARGE: '',
                                    SAFE_CHARGE_RUNNING: '',
                                  },
                                }

    {
      bat_fuel_charge: data.get('ENERGY', 'GUI_BAT_DATA_FUEL_CHARGE'),
      safe_charge_running: data.get('ENERGY', 'SAFE_CHARGE_RUNNING'),
    }
  end
end
