require 'test_helper'

class PricesProviderTest < Minitest::Test
  def test_levels
    VCR.use_cassette('prices_success') do
      assert_equal %w[CHEAP CHEAP CHEAP VERY_CHEAP], prices_provider.levels
    end
  end

  def test_cheapest_grid_power_strict
    config.stub :charger_price_mode, :strict do
      VCR.use_cassette('prices_success') do
        refute_predicate prices_provider, :cheap_grid_power?
      end
    end
  end

  def test_cheapest_grid_power_relaxed
    config.stub :charger_price_mode, :relaxed do
      VCR.use_cassette('prices_success') do
        assert_predicate prices_provider, :cheap_grid_power?
      end
    end
  end

  private

  def prices_provider
    @prices_provider ||= PricesProvider.new(config:)
  end

  def config
    @config ||= Config.from_env
  end
end
