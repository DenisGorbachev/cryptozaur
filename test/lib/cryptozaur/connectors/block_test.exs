defmodule Cryptozaur.Connectors.BlockTest do
  use ExUnit.Case

  alias Cryptozaur.Model.Ticker
  alias Cryptozaur.Drivers.BlockRest
  alias Cryptozaur.Connectors.Block
  import Mock

  setup do
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    :ok
  end

  test "get_tickers" do
    with_mocks [
      {BlockRest, [],
       [
         get_tickers: fn _ ->
           {:ok,
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
            ]}
         end
       ]}
    ] do
      assert {:ok,
              [
                %Ticker{
                  symbol: "BITTREX:BTC:USDT",
                  bid: 11435.27315792,
                  ask: 11438.0,
                  volume_24h_base: 47_684_546.29393488
                },
                %Ticker{
                  symbol: "BITTREX:ETC:BTC",
                  bid: 0.00352811,
                  ask: 0.00353109,
                  volume_24h_base: 3615.70957199
                }
              ]} == Block.get_tickers(%{market: "bittrex", size: 2})
    end
  end

  test "symbol_supported? returns true" do
    with_mocks [
      {BlockRest, [],
       [
         get_tickers: fn _ ->
           {:ok,
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
              }
            ]}
         end
       ]}
    ] do
      assert {:ok, true} == Block.symbol_supported?("Bittrex", "BTC", "USDT")
    end
  end

  test "symbol_supported? returns false" do
    with_mocks [
      {BlockRest, [], [get_tickers: fn _ -> {:ok, []} end]}
    ] do
      assert {:ok, false} == Block.symbol_supported?("Bittrex", "BTC", "USDT")
    end
  end

  test "exchange_supported? returns true" do
    assert Block.exchange_supported?("BITTREX")
  end

  test "exchange_supported? returns false" do
    refute Block.exchange_supported?("MTGOX")
  end
end
