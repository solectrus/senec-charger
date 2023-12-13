require 'test_helper'
require 'prices_provider'
require 'config'

class PricesProviderTest < Minitest::Test
  def test_success_request
    VCR.use_cassette('prices_success') do
      assert_equal 4, prices_provider.levels.size
      prices_provider.levels.each do |level|
        assert_includes %w[NORMAL CHEAP VERY_CHEAP EXPENSIVE VERY_EXPENSIVE],
                        level
      end

      refute_predicate prices_provider, :cheap_grid_power?
    end
  end

  private

  def prices_provider
    @prices_provider ||= PricesProvider.new(config: Config.from_env)
  end
end
