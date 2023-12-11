class PricesProvider
  def initialize(config:)
    @config = config
  end

  def cheap_grid_power?
    false
  end
end
