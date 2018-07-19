defmodule Cryptozaur.Connectors.BinanceTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Trade, Level, Order, Torch}

  @any_secret "secret"
  @exchange "BINANCE"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    success(metronome) = start_supervised(Metronome)
    success(_) = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "iterate_trades" do
    produce_driver(
      [
        {
          {
            :get_aggregated_trades,
            "LTC",
            "BTC",
            %{startTime: ~N[2018-01-21 12:46:00], endTime: ~N[2018-01-21 13:46:00]}
          },
          success([
            %{
              "M" => true,
              "T" => 1_516_538_767_268,
              "a" => 4_969_883,
              "f" => 5_576_266,
              "l" => 5_576_266,
              "m" => false,
              "p" => "0.01630000",
              "q" => "36.17000000"
            },
            %{
              "M" => true,
              "T" => 1_516_538_769_984,
              "a" => 4_969_884,
              "f" => 5_576_267,
              "l" => 5_576_273,
              "m" => false,
              "p" => "0.01630000",
              "q" => "19.06000000"
            }
          ])
        },
        {
          {
            :get_aggregated_trades,
            "LTC",
            "BTC",
            %{startTime: ~N[2018-01-21 13:46:00], endTime: ~N[2018-01-21 14:46:00]}
          },
          success([
            %{
              "M" => true,
              "T" => 1_516_538_769_984,
              "a" => 4_969_884,
              "f" => 5_576_267,
              "l" => 5_576_273,
              "m" => false,
              "p" => "0.01630000",
              "q" => "19.06000000"
            },
            %{
              "M" => true,
              "T" => 1_516_538_771_268,
              "a" => 4_969_883,
              "f" => 5_576_266,
              "l" => 5_576_266,
              "m" => false,
              "p" => "0.01640000",
              "q" => "36.17100000"
            }
          ])
        },
        {
          {
            :get_aggregated_trades,
            "LTC",
            "BTC",
            %{startTime: ~N[2018-01-21 14:46:00], endTime: ~N[2018-01-21 15:00:00]}
          },
          success([
            %{
              "M" => true,
              "T" => 1_516_538_771_268,
              "a" => 4_969_883,
              "f" => 5_576_266,
              "l" => 5_576_266,
              "m" => false,
              "p" => "0.01640000",
              "q" => "36.17100000"
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BinanceRest,
      :public
    )

    me = self()
    stub = fn trades -> send(me, {:trades, trades}) end

    Connector.iterate_trades(@exchange, "LTC", "BTC", ~N[2018-01-21 12:46:00], ~N[2018-01-21 15:00:00], stub)

    assert_receive {
      :trades,
      [
        %Trade{
          amount: 36.17,
          id: nil,
          price: 0.0163,
          symbol: "BINANCE:LTC:BTC",
          timestamp: ~N[2018-01-21 12:46:07.268],
          uid: "4969883"
        },
        %Trade{
          amount: 19.06,
          id: nil,
          price: 0.0163,
          symbol: "BINANCE:LTC:BTC",
          timestamp: ~N[2018-01-21 12:46:09.984],
          uid: "4969884"
        }
      ]
    }

    assert_receive {
      :trades,
      [
        %Trade{
          amount: 19.06,
          id: nil,
          price: 0.0163,
          symbol: "BINANCE:LTC:BTC",
          timestamp: ~N[2018-01-21 12:46:09.984],
          uid: "4969884"
        },
        %Trade{
          amount: 36.171,
          id: nil,
          price: 0.0164,
          symbol: "BINANCE:LTC:BTC",
          timestamp: ~N[2018-01-21 12:46:11.268],
          uid: "4969883"
        }
      ]
    }

    assert_receive {
      :trades,
      [
        %Trade{
          amount: 36.171,
          id: nil,
          price: 0.0164,
          symbol: "BINANCE:LTC:BTC",
          timestamp: ~N[2018-01-21 12:46:11.268],
          uid: "4969883"
        }
      ]
    }
  end

  test "iterate_torches" do
    #    produce_driver(
    #      [
    #        {
    #          {
    #            :get_aggregated_trades,
    #            "LTC",
    #            "BTC",
    #            %{startTime: ~N[2018-01-21 12:46:00], endTime: ~N[2018-01-21 13:46:00]}
    #          },
    #          success(
    #            [
    #              %{
    #                "M" => true,
    #                "T" => 1_516_538_767_268,
    #                "a" => 4_969_883,
    #                "f" => 5_576_266,
    #                "l" => 5_576_266,
    #                "m" => false,
    #                "p" => "0.01630000",
    #                "q" => "36.17000000"
    #              },
    #              %{
    #                "M" => true,
    #                "T" => 1_516_538_769_984,
    #                "a" => 4_969_884,
    #                "f" => 5_576_267,
    #                "l" => 5_576_273,
    #                "m" => false,
    #                "p" => "0.01630000",
    #                "q" => "19.06000000"
    #              }
    #            ]
    #          )
    #        },
    #        {
    #          {
    #            :get_aggregated_trades,
    #            "LTC",
    #            "BTC",
    #            %{startTime: ~N[2018-01-21 13:46:00], endTime: ~N[2018-01-21 14:46:00]}
    #          },
    #          success(
    #            [
    #              %{
    #                "M" => true,
    #                "T" => 1_516_538_769_984,
    #                "a" => 4_969_884,
    #                "f" => 5_576_267,
    #                "l" => 5_576_273,
    #                "m" => false,
    #                "p" => "0.01630000",
    #                "q" => "19.06000000"
    #              },
    #              %{
    #                "M" => true,
    #                "T" => 1_516_538_771_268,
    #                "a" => 4_969_883,
    #                "f" => 5_576_266,
    #                "l" => 5_576_266,
    #                "m" => false,
    #                "p" => "0.01640000",
    #                "q" => "36.17100000"
    #              }
    #            ]
    #          )
    #        },
    #        {
    #          {
    #            :get_aggregated_trades,
    #            "LTC",
    #            "BTC",
    #            %{startTime: ~N[2018-01-21 14:46:00], endTime: ~N[2018-01-21 15:00:00]}
    #          },
    #          success(
    #            [
    #              %{
    #                "M" => true,
    #                "T" => 1_516_538_771_268,
    #                "a" => 4_969_883,
    #                "f" => 5_576_266,
    #                "l" => 5_576_266,
    #                "m" => false,
    #                "p" => "0.01640000",
    #                "q" => "36.17100000"
    #              }
    #            ]
    #          )
    #        }
    #      ],
    #      Cryptozaur.Drivers.BinanceRest,
    #      :public
    #    )

    me = self()
    stub = fn torches -> send(me, {:torches, torches}) end

    Connector.iterate_torches(@exchange, "LTC", "BTC", ~N[2018-01-21 12:46:00], ~N[2018-01-21 15:00:00], 60, stub)

    {:torches, torches} = assert_receive {:torches, _}

    # from & to are inclusive
    assert length(torches) == 135
  end

  test "iterate_trades (no trades at the beginning)" do
    key =
      produce_driver(
        [
          {
            {:all_orders, "LTC", "ETH"},
            success([
              %{
                "clientOrderId" => "aRaw4TYQaliMa3sdRHR7fH",
                "executedQty" => "0.00000000",
                "icebergQty" => "0.00000000",
                "isWorking" => true,
                "orderId" => 4_617_719,
                "origQty" => "1000.00000000",
                "price" => "0.00050330",
                "side" => "BUY",
                "status" => "CANCELED",
                "stopPrice" => "0.00000000",
                "symbol" => "LTCETH",
                "time" => 1_517_154_388_695,
                "timeInForce" => "GTC",
                "type" => "LIMIT"
              }
            ])
          }
        ],
        Cryptozaur.Drivers.BinanceRest
      )

    success(orders) = Connector.get_orders(@exchange, key, @any_secret, "LTC", "ETH")

    assert [
             %Order{
               uid: "4617719",
               pair: "LTC:ETH",
               price: 0.00050330,
               base_diff: 0.0,
               quote_diff: 0.0,
               amount_requested: 1000.0,
               amount_filled: 0.0,
               status: "closed",
               timestamp: ~N[2018-01-28 15:46:28.695]
             }
           ] == orders
  end

  test "get_torches" do
    key =
      produce_driver(
        [
          {
            {:torches, "TRX", "ETH", ~N[2018-03-01 12:00:00], ~N[2018-03-01 15:00:00], 3600},
            success([
              [
                1_519_905_600_000,
                "0.00005152",
                "0.00005280",
                "0.00005122",
                "0.00005222",
                "35059726.00000000",
                1_519_909_199_999,
                "1813.80650519",
                2122,
                "29283383.00000000",
                "1514.57338614",
                "0"
              ],
              [
                1_519_909_200_000,
                "0.00005238",
                "0.00005364",
                "0.00005182",
                "0.00005289",
                "47867600.00000000",
                1_519_912_799_999,
                "2528.09408946",
                3797,
                "40504050.00000000",
                "2139.17941565",
                "0"
              ],
              [
                1_519_912_800_000,
                "0.00005289",
                "0.00005359",
                "0.00005288",
                "0.00005310",
                "44123292.00000000",
                1_519_916_399_999,
                "2349.51250852",
                3207,
                "36523647.00000000",
                "1945.10557672",
                "0"
              ],
              [
                1_519_916_400_000,
                "0.00005312",
                "0.00005321",
                "0.00005211",
                "0.00005257",
                "38174019.00000000",
                1_519_919_999_999,
                "2008.21752155",
                2600,
                "31282237.00000000",
                "1645.61719666",
                "0"
              ]
            ])
          }
        ],
        Cryptozaur.Drivers.BinanceRest
      )

    success(torches) = Connector.get_torches(@exchange, "TRX", "ETH", ~N[2018-03-01 12:00:00], ~N[2018-03-01 15:00:00], 3600)

    assert List.first(torches) == %Torch{
             symbol: "BINANCE:TRX:ETH",
             open: 0.00005152,
             high: 0.00005280,
             low: 0.00005122,
             close: 0.00005222,
             volume: 35_059_726.00000000,
             resolution: 3600,
             timestamp: ~N[2018-03-01 12:00:00.000]
           }
  end

  test "get_levels" do
    key =
      produce_driver(
        [
          {
            {:levels, "LTC", "BTC", 50},
            success(%{
              "bids" => [["0.01571700", "4.83000000", []], ["0.01571600", "0.07000000", []]],
              "asks" => [["0.01571900", "0.07000000", []], ["0.01573100", "16.75000000", []]]
            })
          }
        ],
        Cryptozaur.Drivers.BinanceRest,
        :public
      )

    success({bids, asks}) = Connector.get_levels(@exchange, "LTC", "BTC", 50)

    timestamp = ~N[2018-01-21 12:00:00.000]

    assert Enum.take(bids, 2) |> Enum.map(&Map.put(&1, :timestamp, timestamp)) == [
             %Level{
               symbol: "BINANCE:LTC:BTC",
               price: 0.01571700,
               amount: 4.83000000,
               timestamp: timestamp
             },
             %Level{
               symbol: "BINANCE:LTC:BTC",
               price: 0.01571600,
               amount: 0.07000000,
               timestamp: timestamp
             }
           ]

    assert Enum.take(asks, 2) |> Enum.map(&Map.put(&1, :timestamp, timestamp)) == [
             %Level{
               symbol: "BINANCE:LTC:BTC",
               price: 0.01571900,
               amount: -0.07000000,
               timestamp: timestamp
             },
             %Level{
               symbol: "BINANCE:LTC:BTC",
               price: 0.01573100,
               amount: -16.75000000,
               timestamp: timestamp
             }
           ]
  end

  #  test "Connector should return available balance for specified currency" do
  #    key = produce_driver([
  #      {
  #        {:account},
  #        success(%{"balances" => [%{"asset" => "BTC", "free" => "0.00006183", "locked" => "0.00000000"},
  #            %{"asset" => "LTC", "free" => "0.00000000", "locked" => "0.00000000"},
  #            %{"asset" => "ETH", "free" => "0.00000000", "locked" => "0.00000000"},
  #            %{"asset" => "GAS", "free" => "0.00479520", "locked" => "0.00000000"}],
  #          "buyerCommission" => 0, "canDeposit" => true,
  #          "canTrade" => true, "canWithdraw" => true, "makerCommission" => 10,
  #          "sellerCommission" => 0, "takerCommission" => 10,
  #          "updateTime" => 1514012807004})
  #      }
  #    ], Cryptozaur.Drivers.BinanceRest)
  #
  #    assert success(0.00006183) = Connector.get_balance(@exchange, key, @any_secret, "BTC")
  #  end
  #
  #  test "Connector should cancel order" do
  #    key = produce_driver([
  #      {
  #        {:cancel, "NEOBTC", 19794884, nil, nil},
  #        success(%{"clientOrderId" => "qoCLE54c8upuD0RkO5g8KX", "orderId" => 19794884,
  #        "origClientOrderId" => "68Gqfs0yaKT0zrPawzdkiT", "symbol" => "NEOBTC"})
  #      }
  #    ], Cryptozaur.Drivers.BinanceRest)
  #
  #    assert success(19794884) == Connector.cancel_order(@exchange, key, @any_secret, "NEO", "BTC", 19794884)
  #  end
  #
  #
  #  test "Connector should place a `buy` order and return its uid" do
  #    key = produce_driver([
  #      {
  #        {:order, "NEOBTC", "BUY", "LIMIT", 1, %{"price" => 250, "timeInForce" => "GTC"}, false},
  #        success(%{"clientOrderId" => "0nrx9t4rqa0VGQnWooxyJZ", "executedQty" => "0.00000000",
  #        "fills" => [], "orderId" => 19794828, "origQty" => "1.00000000",
  #        "price" => "250.00000000", "side" => "BUY", "status" => "EXPIRED",
  #        "symbol" => "NEOBTC", "timeInForce" => "GTC",
  #        "transactTime" => 1515414380249, "type" => "LIMIT"})
  #      }
  #    ], Cryptozaur.Drivers.BinanceRest)
  #
  #    assert success(19794828) == Connector.place_order(@exchange, key, @any_secret, "NEO", "BTC", 1, 250)
  #  end
  #
  #  test "Connector should place a `sell` order and return its uid" do
  #    key = produce_driver([
  #      {
  #        {:order, "NEOBTC", "SELL", "LIMIT", 0.1, %{"price" => 250, "timeInForce" => "GTC"}, false},
  #        success(%{"clientOrderId" => "0nrx9t4rqa0VGQnWooxyJZ", "executedQty" => "0.00000000",
  #        "fills" => [], "orderId" => 19794828, "origQty" => "0.10000000",
  #        "price" => "250.00000000", "side" => "SELL", "status" => "EXPIRED",
  #        "symbol" => "NEOBTC", "timeInForce" => "FOK",
  #        "transactTime" => 1515414380249, "type" => "LIMIT"})
  #      }
  #    ], Cryptozaur.Drivers.BinanceRest)
  #
  #    assert success(19794828) == Connector.place_order(@exchange, key, @any_secret, "NEO", "BTC", -0.1, 250)
  #  end
end
