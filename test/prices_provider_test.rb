require 'test_helper'

class PricesProviderTest < Minitest::Test
  def test_levels
    VCR.use_cassette('prices_success') do
      assert_equal %w[CHEAP VERY_CHEAP VERY_CHEAP VERY_CHEAP],
                   prices_provider.levels
    end
  end

  def test_to_s
    VCR.use_cassette('prices_success') do
      assert_equal [
                     '10:00 0.1573 (CHEAP)',
                     '11:00 0.1724 (VERY_CHEAP)',
                     '12:00 0.1536 (VERY_CHEAP)',
                     '13:00 0.1769 (VERY_CHEAP)',
                   ].join(', '),
                   prices_provider.to_s
    end
  end

  def test_to_s_empty
    # Travel to a time where we don't have any prices
    Timecop.travel('2023-05-02 12:10:00 +0200')

    VCR.use_cassette('prices_blank') do
      assert_equal 'No prices found between 2023-05-02 12:00:00 +0200 and 2023-05-02 16:00:00 +0200',
                   prices_provider.to_s
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
