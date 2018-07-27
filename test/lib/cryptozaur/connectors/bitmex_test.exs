defmodule Cryptozaur.Connectors.BitmexTest do
  use ExUnit.Case, async: false
  import OK, only: [success: 1, failure: 1]
  import Cryptozaur.Case

  alias Cryptozaur.Connector
  alias Cryptozaur.Connectors.Bitmex
  alias Cryptozaur.Drivers.BitmexWebsocket, as: Websocket
  alias Cryptozaur.Drivers.BitmexRest, as: Rest
  alias Cryptozaur.Model.{Trade, Level}

  @any_secret "secret"
  @exchange "BITMEX"

  setup do
    success(_) = start_supervised(Cryptozaur.DriverSupervisor)

    :ok
  end

  test "Connector should return Trade structs" do
    produce_driver(
      [
        {
          {:get_trades, "XBT", "USD", %{startTime: ~N[2017-11-10 15:29:12.522], endTime: ~N[2017-11-10 15:29:13.107]}},
          success([
            %{
              "trdMatchID" => "313c6f3b-d054-683f-8871-2fa3cbc10b82",
              "size" => 22563,
              "price" => 6804,
              "side" => "Buy",
              "foreignNotional" => 22563,
              "grossValue" => 331_608_411,
              "homeNotional" => 3.31608411,
              "symbol" => "XBTUSD",
              "tickDirection" => "PlusTick",
              "timestamp" => "2017-11-10T15:29:12.522Z"
            },
            %{
              "trdMatchID" => "90a31623-30b2-b1eb-ecfb-634fb0728fc4",
              "size" => 13253,
              "price" => 6813,
              "side" => "Sell",
              "foreignNotional" => 13253,
              "grossValue" => 194_525_172,
              "homeNotional" => 1.94525172,
              "symbol" => "XBTUSD",
              "tickDirection" => "MinusTick",
              "timestamp" => "2017-11-10T15:29:13.107Z"
            }
          ])
        },
        {
          {:get_trades, "XBT", "USD", %{}},
          success([
            %{
              "trdMatchID" => "313c6f3b-d054-683f-8871-2fa3cbc10b82",
              "size" => 22563,
              "price" => 6804,
              "side" => "Buy",
              "foreignNotional" => 22563,
              "grossValue" => 331_608_411,
              "homeNotional" => 3.31608411,
              "symbol" => "XBTUSD",
              "tickDirection" => "PlusTick",
              "timestamp" => "2017-11-10T15:29:12.522Z"
            },
            %{
              "trdMatchID" => "90a31623-30b2-b1eb-ecfb-634fb0728fc4",
              "size" => 13253,
              "price" => 6813,
              "side" => "Sell",
              "foreignNotional" => 13253,
              "grossValue" => 194_525_172,
              "homeNotional" => 1.94525172,
              "symbol" => "XBTUSD",
              "tickDirection" => "MinusTick",
              "timestamp" => "2017-11-10T15:29:13.107Z"
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BitmexRest,
      :public
    )

    get_trades = Connector.get_trades(@exchange, "XBT", "USD", ~N[2017-11-10 15:29:12.522], ~N[2017-11-10 15:29:13.107])
    get_latest_trades = Connector.get_latest_trades(@exchange, "XBT", "USD")

    assert get_trades ==
             success([
               %Trade{
                 uid: "313c6f3b-d054-683f-8871-2fa3cbc10b82",
                 symbol: "BITMEX:XBT:USD",
                 price: 6804.0,
                 amount: 3.31608411,
                 timestamp: ~N[2017-11-10 15:29:12.522]
               },
               %Trade{
                 uid: "90a31623-30b2-b1eb-ecfb-634fb0728fc4",
                 symbol: "BITMEX:XBT:USD",
                 price: 6813.0,
                 amount: -1.94525172,
                 timestamp: ~N[2017-11-10 15:29:13.107]
               }
             ])

    assert get_latest_trades == get_trades
  end

  test "Connector should place a `buy` order and return its uid" do
    key =
      produce_driver(
        [
          {
            {:place_order, "XBT", "USD", 1, 5000, []},
            success(%{
              "side" => "Buy",
              "transactTime" => "2017-11-04T10:39:17.918Z",
              "ordType" => "Limit",
              "displayQty" => nil,
              "stopPx" => nil,
              "settlCurrency" => "XBt",
              "triggered" => "",
              "orderID" => "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf",
              "currency" => "USD",
              "pegOffsetValue" => nil,
              "price" => 5000,
              "pegPriceType" => "",
              "text" => "Submitted via API.",
              "workingIndicator" => true,
              "multiLegReportingType" => "SingleSecurity",
              "timestamp" => "2017-11-04T10:39:17.918Z",
              "cumQty" => 0,
              "ordRejReason" => "",
              "avgPx" => nil,
              "orderQty" => 1,
              "simpleOrderQty" => nil,
              "ordStatus" => "New",
              "timeInForce" => "GoodTillCancel",
              "clOrdLinkID" => "",
              "simpleLeavesQty" => 0.0002,
              "leavesQty" => 1,
              "exDestination" => "XBME",
              "symbol" => "XBTUSD",
              "account" => 90042,
              "clOrdID" => "",
              "simpleCumQty" => 0,
              "execInst" => "",
              "contingencyType" => ""
            })
          }
        ],
        Rest
      )

    assert success("0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf") == Connector.place_order(@exchange, key, @any_secret, "XBT", "USD", 1, 5000)
  end

  test "Connector should return an error if order can't be placed" do
    key =
      produce_driver(
        [
          {
            {:place_order, "XBT", "USD", 1, 5000, []},
            success(%{
              "side" => "Buy",
              "transactTime" => "2017-11-04T10:39:17.918Z",
              "ordType" => "Limit",
              "displayQty" => nil,
              "stopPx" => nil,
              "settlCurrency" => "XBt",
              "triggered" => "",
              "orderID" => "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf",
              "currency" => "USD",
              "pegOffsetValue" => nil,
              "price" => 5000,
              "pegPriceType" => "",
              "text" => "Canceled: Order had execInst of ParticipateDoNotInitiate\nSubmitted via API.",
              "workingIndicator" => true,
              "multiLegReportingType" => "SingleSecurity",
              "timestamp" => "2017-11-04T10:39:17.918Z",
              "cumQty" => 0,
              "ordRejReason" => "",
              "avgPx" => nil,
              "orderQty" => 1,
              "simpleOrderQty" => nil,
              "ordStatus" => "Canceled",
              "timeInForce" => "GoodTillCancel",
              "clOrdLinkID" => "",
              "simpleLeavesQty" => 0.0002,
              "leavesQty" => 1,
              "exDestination" => "XBME",
              "symbol" => "XBTUSD",
              "account" => 90042,
              "clOrdID" => "",
              "simpleCumQty" => 0,
              "execInst" => "",
              "contingencyType" => ""
            })
          }
        ],
        Rest
      )

    assert failure("Canceled: Order had execInst of ParticipateDoNotInitiate\nSubmitted via API.") == Connector.place_order(@exchange, key, @any_secret, "XBT", "USD", 1, 5000)
  end

  test "Connector change existing order and return its uid" do
    key =
      produce_driver(
        [
          {
            {:change_order, "680dcacb-02ae-3c3e-4ef0-91b92a9c94cf", %{price: 5500, amount: 2}, []},
            success(%{
              "side" => "Buy",
              "transactTime" => "2017-11-04T11:04:18.004Z",
              "ordType" => "Limit",
              "displayQty" => nil,
              "stopPx" => nil,
              "settlCurrency" => "XBt",
              "triggered" => "",
              "orderID" => "680dcacb-02ae-3c3e-4ef0-91b92a9c94cf",
              "currency" => "USD",
              "pegOffsetValue" => nil,
              "price" => 5500,
              "pegPriceType" => "",
              "text" => "Amended orderQty price: Amended via API.\nSubmitted via API.",
              "workingIndicator" => true,
              "multiLegReportingType" => "SingleSecurity",
              "timestamp" => "2017-11-04T11:04:18.004Z",
              "cumQty" => 0,
              "ordRejReason" => "",
              "avgPx" => nil,
              "orderQty" => 2,
              "simpleOrderQty" => nil,
              "ordStatus" => "New",
              "timeInForce" => "GoodTillCancel",
              "clOrdLinkID" => "",
              "simpleLeavesQty" => 0.0004,
              "leavesQty" => 2,
              "exDestination" => "XBME",
              "symbol" => "XBTUSD",
              "account" => 90042,
              "clOrdID" => "",
              "simpleCumQty" => 0,
              "execInst" => "",
              "contingencyType" => ""
            })
          }
        ],
        Rest
      )

    assert success("680dcacb-02ae-3c3e-4ef0-91b92a9c94cf") ==
             Connector.change_order(
               @exchange,
               key,
               @any_secret,
               "XBT",
               "USD",
               "680dcacb-02ae-3c3e-4ef0-91b92a9c94cf",
               2,
               5500
             )
  end

  test "Connector should cancel order" do
    key =
      produce_driver(
        [
          {
            {:delete_order, "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf"},
            success([%{"side" => "Buy", "transactTime" => "2017-11-04T10:39:17.918Z", "ordType" => "Limit", "displayQty" => nil, "stopPx" => nil, "settlCurrency" => "XBt", "triggered" => "", "orderID" => "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf", "currency" => "USD", "pegOffsetValue" => nil, "price" => 5000, "pegPriceType" => "", "text" => "Canceled: Canceled via API.\nSubmitted via API.", "workingIndicator" => false, "multiLegReportingType" => "SingleSecurity", "timestamp" => "2017-11-04T10:44:18.553Z", "cumQty" => 0, "ordRejReason" => "", "avgPx" => nil, "orderQty" => 1, "simpleOrderQty" => nil, "ordStatus" => "Canceled", "timeInForce" => "GoodTillCancel", "clOrdLinkID" => "", "simpleLeavesQty" => 0, "leavesQty" => 0, "exDestination" => "XBME", "symbol" => "XBTUSD", "account" => 90042, "clOrdID" => "", "simpleCumQty" => 0, "execInst" => "", "contingencyType" => ""}])
          }
        ],
        Rest
      )

    assert success("0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf") == Connector.cancel_order(@exchange, key, @any_secret, "XBT", "USD", "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf")
  end

  test "Connector should provide order book tracker" do
    produce_driver(
      [
        {
          {:subscribe, "orderBookL2", "XBT", "USD"},
          success(nil)
        },
        {
          {:get_descriptor, "orderBookL2", "XBT", "USD"},
          success({Websocket, :public, {:data, "orderBookL2", "XBTUSD"}})
        }
      ],
      Websocket,
      :public
    )

    success(pid) = Bitmex.subscribe_levels("XBT", "USD")

    send(
      pid,
      {{:data, "orderBookL2", "XBTUSD"},
       %{
         insert: [
           %{"symbol" => "XBTUSD", "id" => 17_999_993_000, "side" => "Sell", "size" => 2.1, "price" => 5890.2},
           %{"symbol" => "XBTUSD", "id" => 17_999_996_000, "side" => "Buy", "size" => 3.1, "price" => 5870.2}
         ],
         initial: true
       }}
    )

    assert_receive {Bitmex,
                    %{
                      sells: [
                        %Level{amount: 2.1, price: 5890.2}
                      ],
                      buys: [
                        %Level{amount: 3.1, price: 5870.2}
                      ]
                    }}

    send(
      pid,
      {{:data, "orderBookL2", "XBTUSD"},
       %{
         insert: [
           %{"id" => 8_799_410_890, "price" => 5895.0, "side" => "Sell", "size" => 5.0, "symbol" => "XBTUSD"},
           %{"id" => 8_799_410_880, "price" => 5871.2, "side" => "Buy", "size" => 10.0, "symbol" => "XBTUSD"}
         ]
       }}
    )

    assert_receive {Bitmex,
                    %{
                      sells: [
                        %Level{amount: 2.1, price: 5890.2},
                        %Level{amount: 5.0, price: 5895.0}
                      ],
                      buys: [
                        %Level{amount: 10.0, price: 5871.2},
                        %Level{amount: 3.1, price: 5870.2}
                      ]
                    }}

    send(
      pid,
      {{:data, "orderBookL2", "XBTUSD"},
       %{
         delete: [
           %{"id" => 17_999_996_000, "side" => "Buy", "symbol" => "XBTUSD"}
         ]
       }}
    )

    assert_receive {Bitmex,
                    %{
                      sells: [
                        %Level{amount: 2.1, price: 5890.2},
                        %Level{amount: 5.0, price: 5895.0}
                      ],
                      buys: [
                        %Level{amount: 10.0, price: 5871.2}
                      ]
                    }}

    send(
      pid,
      {{:data, "orderBookL2", "XBTUSD"},
       %{
         update: [
           %{"id" => 17_999_993_000, "side" => "Sell", "size" => 5.2, "symbol" => "XBTUSD"}
         ]
       }}
    )

    assert_receive {Bitmex,
                    %{
                      sells: [
                        %Level{amount: 5.2, price: 5890.2},
                        %Level{amount: 5.0, price: 5895.0}
                      ],
                      buys: [
                        %Level{amount: 10.0, price: 5871.2}
                      ]
                    }}
  end

  test "Connector should provide trade tracker" do
    produce_driver(
      [
        {
          {:subscribe, "trade", "XBT", "USD"},
          success(nil)
        },
        {
          {:get_descriptor, "trade", "XBT", "USD"},
          success({Websocket, :public, {:data, "trade", "XBTUSD"}})
        }
      ],
      Websocket,
      :public
    )

    success(pid) = Bitmex.subscribe_trades("XBT", "USD")

    send(
      pid,
      {{:data, "trade", "XBTUSD"},
       %{
         insert: [
           %{
             "foreignNotional" => 6073,
             "grossValue" => 69_857_719,
             "homeNotional" => 0.69857719,
             "price" => 8693.50000000,
             "side" => "Buy",
             "size" => 6073,
             "symbol" => "XBTUSD",
             "tickDirection" => "PlusTick",
             "timestamp" => "2018-02-12T12:23:38.530Z",
             "trdMatchID" => "cdf78ca6-1fad-fa2a-bfd7-7d9e3cd58369"
           }
         ],
         initial: true
       }}
    )

    assert_receive {Bitmex,
                    [
                      %Trade{
                        uid: "cdf78ca6-1fad-fa2a-bfd7-7d9e3cd58369",
                        symbol: "BITMEX:XBT:USD",
                        timestamp: ~N[2018-02-12 12:23:38.530],
                        price: 8693.5,
                        amount: 0.69857719
                      }
                    ]}

    send(
      pid,
      {{:data, "trade", "XBTUSD"},
       %{
         insert: [
           %{
             "foreignNotional" => 1,
             "grossValue" => 11504,
             "homeNotional" => 0.00011504,
             "price" => 8693,
             "side" => "Buy",
             "size" => 1,
             "symbol" => "XBTUSD",
             "tickDirection" => "MinusTick",
             "timestamp" => "2018-02-12T12:23:39.548Z",
             "trdMatchID" => "96d7bf03-e887-39fc-b623-7d8534128c9e"
           }
         ]
       }}
    )

    assert_receive {Bitmex,
                    [
                      %Trade{
                        uid: "96d7bf03-e887-39fc-b623-7d8534128c9e",
                        symbol: "BITMEX:XBT:USD",
                        timestamp: ~N[2018-02-12 12:23:39.548],
                        price: 8693.0,
                        amount: 0.00011504
                      }
                    ]}
  end

  test "should get link" do
    assert "https://www.bitmex.com/app/trade/XBTUSD" == Connector.get_link(@exchange, "XBT", "USD")
  end
end
