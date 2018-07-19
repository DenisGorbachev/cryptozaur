defmodule Cryptozaur.Drivers.BlockRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  alias Cryptozaur.Drivers.BlockRest

  setup_all do
    HTTPoison.start()

    :ok
  end

  test "get_markets" do
    use_cassette "block/get_markets" do
      results = BlockRest.get_markets()

      {:ok, exchanges} = results

      assert %{
               "display_name" => "Binance",
               "home_url" => "www.binance.com",
               "logo" => "https://blockchains.oss-cn-shanghai.aliyuncs.com/static/Exchange/binance.png",
               "name" => "binance",
               "ping" => 1.74000000,
               "status" => "enable",
               "volume" => 2_304_141_457.39879990
             } == List.first(exchanges)
    end
  end

  test "get_tickers" do
    use_cassette "block/get_tickers" do
      result = BlockRest.get_tickers(%{market: "bittrex", size: 2})

      assert {:ok,
              [
                %{
                  "ask" => 11438,
                  "base_volume" => 47_684_546.29393488,
                  "bid" => 11435.27315792,
                  "change_daily" => 0.08910000,
                  "has_kline" => true,
                  "high" => 11639.99999999,
                  "increase" => 0.08910000,
                  "last" => 11438,
                  "low" => 10731.13655680,
                  "market" => "bittrex",
                  "symbol_pair" => "BTC_USDT",
                  "timestamps" => 1_519_115_197_891,
                  "usd_rate" => 1.00018000,
                  "vol" => 4283.63002139
                },
                %{
                  "ask" => 0.00353109,
                  "base_volume" => 3615.70957199,
                  "bid" => 0.00352811,
                  "change_daily" => 0.07000000,
                  "has_kline" => true,
                  "high" => 0.00375233,
                  "increase" => 0.07000000,
                  "last" => 0.00352993,
                  "low" => 0.00336000,
                  "market" => "bittrex",
                  "symbol_pair" => "ETC_BTC",
                  "timestamps" => 1_519_115_195_420,
                  "usd_rate" => 11433.79830800,
                  "vol" => 1_018_690.03967595
                }
              ]} == result
    end
  end
end
