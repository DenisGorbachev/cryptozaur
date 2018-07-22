defmodule Cryptozaur.Connectors.OkexTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Ticker, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_ticker" do
    produce_driver(
      [
        {
          {:get_ticker, "BTC", "USDT"},
          success(%{
            "date" => "1517896342",
            "ticker" => %{"buy" => "6600.0003", "high" => "8316.9499", "last" => "6594.0003", "low" => "6100.0000", "sell" => "6603.1398", "vol" => "164520.4297"}
          })
        }
      ],
      Cryptozaur.Drivers.OkexRest,
      :public
    )

    assert success(%Ticker{
             symbol: "OKEX:BTC:USDT",
             bid: 6600.0003,
             ask: 6603.1398,
             volume_24h_base: 164_520.4297
           }) == Connector.get_ticker("OKEX", "BTC", "USDT")
  end

  test "get_tickers" do
    produce_driver(
      [
        {
          {:get_tickers},
          success([
            %{
              "buy" => "0.01800005",
              "change" => "-0.00037196",
              "changePercentage" => "-2.02%",
              "close" => "0.01802871",
              "createdDate" => 1_518_058_304_372,
              "currencyId" => 12,
              "dayHigh" => "0.01843800",
              "dayLow" => "0.01796600",
              "high" => "0.01878000",
              "last" => "0.01800004",
              "low" => "0.01796600",
              "marketFrom" => 103,
              "name" => "OKEx",
              "open" => "0.01828037",
              "orderIndex" => 0,
              "productId" => 12,
              "sell" => "0.01804973",
              "symbol" => "ltc_btc",
              "volume" => "2208994.07192012"
            },
            %{
              "buy" => "0.10031327",
              "change" => "+0.00063893",
              "changePercentage" => "+0.64%",
              "close" => "0.10046252",
              "createdDate" => 1_518_058_304_372,
              "currencyId" => 13,
              "dayHigh" => "0.10198996",
              "dayLow" => "0.09881000",
              "high" => "0.10205000",
              "last" => "0.10099989",
              "low" => "0.09881000",
              "marketFrom" => 104,
              "name" => "OKEx",
              "open" => "0.10004851",
              "orderIndex" => 0,
              "productId" => 13,
              "sell" => "0.10099989",
              "symbol" => "eth_btc",
              "volume" => "743329.18198642"
            }
          ])
        }
      ],
      Cryptozaur.Drivers.OkexRest,
      :public
    )

    assert success([
             %Ticker{
               symbol: "OKEX:LTC:BTC",
               bid: 0.01800005,
               ask: 0.01804973,
               volume_24h_base: 2_208_994.07192012
             },
             %Ticker{
               symbol: "OKEX:ETH:BTC",
               bid: 0.10031327,
               ask: 0.10099989,
               volume_24h_base: 743_329.18198642
             }
           ]) == Connector.get_tickers("OKEX")
  end

  test "get_balances" do
    key =
      produce_driver(
        [
          {
            {:get_userinfo},
            success(%{
              "info" => %{
                "funds" => %{
                  "borrow" => %{
                    "neo" => "0.234",
                    "hot" => "0"
                  },
                  "free" => %{
                    "neo" => "0.53243",
                    "hot" => "0"
                  },
                  "freezed" => %{
                    "neo" => "0.190",
                    "hot" => "0"
                  }
                }
              },
              "result" => true
            })
          }
        ],
        Cryptozaur.Drivers.OkexRest
      )

    assert success([
             %Balance{available_amount: 0.0, total_amount: 0.0, currency: "HOT"},
             %Balance{available_amount: 0.53243, total_amount: 0.53243 + 0.190, currency: "NEO"}
           ]) == Connector.get_balances("OKEX", key, "secret")
  end

  test "place_order" do
    key =
      produce_driver(
        [
          {
            {:trade, "ltc_eth", "buy", 0.1, 0.00001},
            success(%{"order_id" => 30_872_494, "result" => true})
          }
        ],
        Cryptozaur.Drivers.OkexRest
      )

    assert success("30872494") == Connector.place_order("OKEX", key, "secret", "LTC", "ETH", 0.1, 0.00001)
  end

  test "cancel_order" do
    key =
      produce_driver(
        [
          {
            {:cancel_order, "ltc_eth", "30872494"},
            success(%{"order_id" => "30872494", "result" => true})
          }
        ],
        Cryptozaur.Drivers.OkexRest
      )

    assert success("30872494") == Connector.cancel_order("OKEX", key, "secret", "LTC", "ETH", "30872494")
  end
end
