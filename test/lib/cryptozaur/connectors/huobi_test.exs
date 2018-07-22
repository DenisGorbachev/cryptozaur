defmodule Cryptozaur.Connectors.HuobiTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Trade, Ticker, Balance}

  @any_secret "secret"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_symbols" do
    produce_driver(
      [
        {
          {:get_symbols},
          success([
            %{
              "base-currency" => "ltc",
              "quote-currency" => "usdt",
              "amount-precision" => 4,
              "price-precision" => 2,
              "symbol-partition" => "main"
            },
            %{
              "base-currency" => "omg",
              "quote-currency" => "usdt",
              "amount-precision" => 4,
              "price-precision" => 2,
              "symbol-partition" => "main"
            }
          ])
        }
      ],
      Cryptozaur.Drivers.HuobiRest,
      :public
    )

    assert success(["HUOBI:LTC:USDT", "HUOBI:OMG:USDT"]) == Connector.get_symbols("HUOBI")
  end

  test "get_ticker" do
    produce_driver(
      [
        {
          {:get_ticker, "LINK", "BTC"},
          success(%{
            "amount" => 1_670_389.546546936,
            "ask" => [7.394e-5, 12836.87],
            "bid" => [7.3e-5, 740.14],
            "close" => 7.342e-5,
            "count" => 4440,
            "high" => 1.1159e-4,
            "id" => 1_459_417_540,
            "low" => 6.1e-5,
            "open" => 6.1e-5,
            "version" => 1_459_417_540,
            "vol" => 137.63668925234393
          })
        }
      ],
      Cryptozaur.Drivers.HuobiRest,
      :public
    )

    assert success(%Ticker{
             symbol: "HUOBI:LINK:BTC",
             bid: 0.00007300,
             ask: 0.00007394,
             volume_24h_base: 1_670_389.546546936,
             volume_24h_quote: 137.63668925234393
           }) == Connector.get_ticker("HUOBI", "LINK", "BTC")
  end

  #  # TODO: implement get_tickers
  #  test "get_tickers"

  test "get_latest_trades" do
    produce_driver(
      [
        {
          {:get_latest_trades, "OMG", "USDT", 2000},
          success([
            %{
              "data" => [
                %{
                  "amount" => 0.9130,
                  "ts" => 1_517_335_786_419,
                  "id" => 17_229_151_601_014_757_272,
                  "price" => 0.016470,
                  "direction" => "sell"
                }
              ],
              "id" => 1_708_482_140,
              "ts" => 1_517_335_786_419
            },
            %{
              "data" => [
                %{
                  "amount" => 1.2300,
                  "ts" => 1_517_335_786_212,
                  "id" => 17_229_150_141_014_741_190,
                  "price" => 0.016455,
                  "direction" => "sell"
                }
              ],
              "id" => 1_708_482_141,
              "ts" => 1_517_335_786_212
            }
          ])
        }
      ],
      Cryptozaur.Drivers.HuobiRest,
      :public
    )

    assert success([
             %Trade{
               uid: "17229151601014757272",
               symbol: "HUOBI:OMG:USDT",
               price: 0.016470,
               amount: -0.913,
               timestamp: ~N[2018-01-30 18:09:46.419]
             },
             %Trade{
               uid: "17229150141014741190",
               symbol: "HUOBI:OMG:USDT",
               price: 0.016455,
               amount: -1.23,
               timestamp: ~N[2018-01-30 18:09:46.212]
             }
           ]) == Connector.get_latest_trades("HUOBI", "OMG", "USDT")
  end

  #  test "get_orders" do
  #    key =
  #      produce_driver(
  #        [
  #          {
  #            {:get_orders, %{}},
  #            success([
  #              %{
  #                "account-id" => 2_019_764,
  #                "amount" => "0.100000000000000000",
  #                "canceled-at" => 0,
  #                "created-at" => 1_517_323_628_646,
  #                "field-amount" => "0.100000000000000000",
  #                "field-cash-amount" => "0.001106000000000000",
  #                "field-fees" => "0.000002212000000000",
  #                "finished-at" => 1_517_323_668_177,
  #                "id" => 1_011_768_083,
  #                "price" => "0.011060000000000000",
  #                "source" => "api",
  #                "state" => "filled",
  #                "symbol" => "eoseth",
  #                "type" => "sell-limit"
  #              },
  #              %{
  #                "account-id" => 2_019_764,
  #                "amount" => "1.000000000000000000",
  #                "canceled-at" => 1_517_322_129_912,
  #                "created-at" => 1_517_314_091_356,
  #                "field-amount" => "0.0",
  #                "field-cash-amount" => "0.0",
  #                "field-fees" => "0.0",
  #                "finished-at" => 1_517_322_129_959,
  #                "id" => 1_009_318_443,
  #                "price" => "0.010000000000000000",
  #                "source" => "api",
  #                "state" => "canceled",
  #                "symbol" => "eoseth",
  #                "type" => "buy-limit"
  #              },
  #              %{
  #                "account-id" => 2_019_764,
  #                "amount" => "1.000000000000000000",
  #                "canceled-at" => 0,
  #                "created-at" => 1_517_314_091_356,
  #                "field-amount" => "0.0",
  #                "field-cash-amount" => "0.0",
  #                "field-fees" => "0.0",
  #                "finished-at" => 0,
  #                "id" => 1_009_318_443,
  #                "price" => "0.010000000000000000",
  #                "source" => "api",
  #                "state" => "submitted",
  #                "symbol" => "eoseth",
  #                "type" => "buy-limit"
  #              }
  #            ])
  #          }
  #        ],
  #        Cryptozaur.Drivers.HuobiRest
  #      )
  #
  #    assert success([
  #             %Order{
  #               uid: "1011768083",
  #               pair: "EOS:ETH",
  #               timestamp: ~N[2018-01-30 14:47:08.646],
  #               price: 0.01106,
  #               amount_requested: -0.1,
  #               amount_filled: -0.1,
  #               status: "closed",
  #               base_diff: -0.1,
  #               quote_diff: 0.001103788
  #             },
  #             %Order{
  #               uid: "1009318443",
  #               pair: "EOS:ETH",
  #               timestamp: ~N[2018-01-30 12:08:11.356],
  #               price: 0.01,
  #               amount_requested: 1.0,
  #               amount_filled: 0.0,
  #               status: "closed",
  #               base_diff: 0.0,
  #               quote_diff: 0.0
  #             },
  #             %Order{
  #               uid: "1009318443",
  #               pair: "EOS:ETH",
  #               timestamp: ~N[2018-01-30 12:08:11.356],
  #               price: 0.01,
  #               amount_requested: 1.0,
  #               amount_filled: 0.0,
  #               status: "opened",
  #               base_diff: 0.0,
  #               quote_diff: 0.0
  #             }
  #           ]) == Connector.get_orders("HUOBI", key, @any_secret)
  #  end

  test "get_balances" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            success(%{
              "id" => 2_019_764,
              "list" => [
                %{
                  "balance" => "0.000000000000000000",
                  "currency" => "act",
                  "type" => "trade"
                },
                %{
                  "balance" => "0.100000000000000000",
                  "currency" => "act",
                  "type" => "frozen"
                },
                %{
                  "balance" => "0.500000000000000000",
                  "currency" => "eth",
                  "type" => "trade"
                },
                %{
                  "balance" => "0.000000000000000000",
                  "currency" => "eth",
                  "type" => "frozen"
                }
              ],
              "state" => "working",
              "type" => "spot"
            })
          }
        ],
        Cryptozaur.Drivers.HuobiRest
      )

    assert success([
             %Balance{
               currency: "ACT",
               total_amount: 0.1,
               available_amount: 0.0
             },
             %Balance{
               currency: "ETH",
               total_amount: 0.5,
               available_amount: 0.5
             }
           ]) == Connector.get_balances("HUOBI", key, @any_secret)
  end

  test "place_order" do
    key =
      produce_driver(
        [
          {
            {:place_order, "LTC", "BTC", "buy-limit", 1.0, %{price: 50.0}},
            success("123123123")
          }
        ],
        Cryptozaur.Drivers.HuobiRest
      )

    assert success("123123123") == Connector.place_order("HUOBI", key, @any_secret, "LTC", "BTC", 1.0, 50.0)
  end

  test "cancel_order" do
    key =
      produce_driver(
        [
          {
            {:cancel_order, "123123123"},
            success("123123123")
          }
        ],
        Cryptozaur.Drivers.HuobiRest
      )

    assert success("123123123") == Connector.cancel_order("HUOBI", key, @any_secret, "LTC", "BTC", "123123123")
  end
end
