defmodule Cryptozaur.Drivers.CoinmarketcapRestTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1]

  alias Cryptozaur.Drivers.CoinmarketcapRest, as: Rest

  setup_all do
    HTTPoison.start()

    success(driver) = Rest.start_link(%{key: "key", secret: "secret"})

    %{driver: driver}
  end

  test "Coinmarketcap get_briefs should return briefs", %{driver: driver} do
    use_cassette "coinmarketcap/get_briefs" do
      success([
        %{
          "24h_volume_usd" => "12842400000.0",
          "available_supply" => "16767862.0",
          "id" => "bitcoin",
          "last_updated" => "1514473761",
          "market_cap_usd" => "247280691273",
          "max_supply" => "21000000.0",
          "name" => "Bitcoin",
          "percent_change_1h" => "2.28",
          "percent_change_24h" => "-7.06",
          "percent_change_7d" => "-9.02",
          "price_btc" => "1.0",
          "price_usd" => "14747.3",
          "rank" => "1",
          "symbol" => "BTC",
          "total_supply" => "16767862.0"
        },
        %{
          "24h_volume_usd" => "2336750000.0",
          "available_supply" => "96623187.0",
          "id" => "ethereum",
          "last_updated" => "1514473750",
          "market_cap_usd" => "71473427270.0",
          "max_supply" => nil,
          "name" => "Ethereum",
          "percent_change_1h" => "1.91",
          "percent_change_24h" => "-3.52",
          "percent_change_7d" => "-11.45",
          "price_btc" => "0.0510959",
          "price_usd" => "739.713",
          "rank" => "2",
          "symbol" => "ETH",
          "total_supply" => "96623187.0"
        }
      ]) == Rest.get_briefs(driver, %{limit: 2})
    end
  end

  test "Coinmarketcap get_briefs should return all known briefs", %{driver: driver} do
    use_cassette "coinmarketcap/get_all_briefs" do
      success(briefs) = Rest.get_briefs(driver, %{limit: 0})
      assert length(briefs) == 1376
    end
  end
end
