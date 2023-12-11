class ForecastProvider
  def initialize(config:)
    @config = config
  end

  def sunshine_ahead?
    false
  end
end
