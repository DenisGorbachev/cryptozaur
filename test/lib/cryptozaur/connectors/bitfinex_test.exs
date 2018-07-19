defmodule Cryptozaur.Connectors.BitfinexTest do
  use ExUnit.Case
  import OK, only: [success: 1, failure: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Connector}
  alias Cryptozaur.Model.{Trade, Level, Candle, Ticker}
  alias Cryptozaur.Drivers.BitfinexWebsocket, as: Websocket
  alias Cryptozaur.Connectors.Bitfinex

  @exchange "BITFINEX"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    success(_pid) = start_supervised(Cryptozaur.DriverSupervisor)

    :ok
  end

  test "Connector should return Trade structs" do
    produce_driver(
      [
        {
          {:get_trades, "BTC", "USD", %{limit: 1000}},
          success([
            [62_183_353, 1_504_556_829_000, 0.32583922, 4224.4],
            [40_379_202, 1_498_751_848_000, -0.483893, 2490.3]
          ])
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success([
             %Trade{
               uid: "62183353",
               symbol: "BITFINEX:BTC:USD",
               price: 4224.4,
               amount: 0.32583922,
               timestamp: ~N[2017-09-04 20:27:09.000]
             },
             %Trade{
               uid: "40379202",
               symbol: "BITFINEX:BTC:USD",
               price: 2490.3,
               amount: -0.483893,
               timestamp: ~N[2017-06-29 15:57:28.000]
             }
           ]) == Cryptozaur.Connectors.Bitfinex.get_latest_trades("BTC", "USD")
  end

  test "get_ticker" do
    produce_driver(
      [
        {
          {:get_ticker, "BTC", "USD"},
          success([
            8001.40000000,
            68.63572272,
            8003.60000000,
            27.00050559,
            641,
            0.08710000,
            8001,
            103_681.92705866,
            8488.90000000,
            7175.10000000
          ])
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success(%Ticker{
             symbol: "BITFINEX:BTC:USD",
             bid: 8001.40000000,
             ask: 8003.60000000,
             volume_24h_base: 103_681.92705866
           }) == Connector.get_ticker("BITFINEX", "BTC", "USD")
  end

  test "get_tickers" do
    produce_driver(
      [
        {
          {:get_tickers},
          success([
            [
              "tBTCUSD",
              8156.60000000,
              109.54143550,
              8156.90000000,
              53.14059595,
              715.10000000,
              0.09610000,
              8156.90000000,
              101_959.04679148,
              8488.90000000,
              7269.10000000
            ],
            [
              "tLTCUSD",
              145.77000000,
              2030.95146512,
              145.92000000,
              707.20334951,
              7.99000000,
              0.05790000,
              145.99000000,
              429_860.00509965,
              157.20000000,
              134.68000000
            ]
          ])
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success([
             %Ticker{
               symbol: "BITFINEX:BTC:USD",
               bid: 8156.60000000,
               ask: 8156.90000000,
               volume_24h_base: 101_959.04679148
             },
             %Ticker{
               symbol: "BITFINEX:LTC:USD",
               bid: 145.77000000,
               ask: 145.92000000,
               volume_24h_base: 429_860.00509965
             }
           ]) == Connector.get_tickers("BITFINEX")
  end

  test "Connector should return Level structs" do
    produce_driver(
      [
        {
          {:get_order_book, "BTC", "USD", %{}},
          success([
            [4275.4, 2, 0.47486541],
            [4286.6, 1, -0.01]
          ])
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success({
             [
               %Level{
                 symbol: "BITFINEX:BTC:USD",
                 price: 4275.4,
                 amount: 0.47486541
               }
             ],
             [
               %Level{
                 symbol: "BITFINEX:BTC:USD",
                 price: 4286.6,
                 amount: -0.01
               }
             ]
           }) == Cryptozaur.Connectors.Bitfinex.get_levels("BTC", "USD")
  end

  test "Connector should return Candle structs" do
    produce_driver(
      [
        {
          {:get_candles, "BTC", "USD", 1, %{}},
          success([
            [1_511_708_760_000, 9009.9, 9014.1, 9014.1, 9008, 9.25789982],
            [1_511_708_700_000, 9006.9, 9010, 9010.4, 9006.9, 30.3807757]
          ])
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success([
             %Candle{
               symbol: "BITFINEX:BTC:USD",
               timestamp: ~N[2017-11-26 15:06:00.000],
               open: 9009.9,
               close: 9014.1,
               high: 9014.1,
               low: 9008.0,
               resolution: 1
             },
             %Candle{
               symbol: "BITFINEX:BTC:USD",
               timestamp: ~N[2017-11-26 15:05:00.000],
               open: 9006.9,
               close: 9010.0,
               high: 9010.4,
               low: 9006.9,
               resolution: 1
             }
           ]) == Cryptozaur.Connectors.Bitfinex.get_candles("BTC", "USD", 1)
  end

  test "Connector should check if the pair is valid (true)" do
    produce_driver(
      [
        {
          {:get_ticker, "BTC", "USD"},
          success([4000.0, 109.54143550, 4000.1, 53.14059595, 715.10000000, 0.09610000, 8156.90000000, 101_959.04679148, 8488.90000000, 7269.10000000])
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success(true) == Connector.pair_valid?(@exchange, "BTC", "USD")
  end

  test "Connector should check if the pair is valid (false)" do
    produce_driver(
      [
        {
          {:get_ticker, "BTC", "USD"},
          failure("10020: symbol: invalid")
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert success(false) == Connector.pair_valid?(@exchange, "BTC", "USD")
  end

  test "Connector should check if the pair is valid (forward unexpected error)" do
    produce_driver(
      [
        {
          {:get_ticker, "BTC", "USD"},
          failure("API_ERROR")
        }
      ],
      Cryptozaur.Drivers.BitfinexRest,
      :public
    )

    assert failure("API_ERROR") == Connector.pair_valid?(@exchange, "BTC", "USD")
  end

  test "credentials_valid?" do
    key =
      produce_driver(
        [
          {
            {:get_balances, %{}},
            success([])
          },
          {
            {:get_balances, %{}},
            failure("10100: apikey: invalid")
          },
          {
            {:get_balances, %{}},
            failure("unknown error")
          }
        ],
        Cryptozaur.Drivers.BitfinexRest
      )

    assert success(true) = Connector.credentials_valid?(@exchange, key, "secret")
    assert success(false) = Connector.credentials_valid?(@exchange, key, "secret")
    assert failure("unknown error") = Connector.credentials_valid?(@exchange, key, "secret")
  end

  test "should get link" do
    assert "https://www.bitfinex.com/t/LTC:BTC" == Connector.get_link(@exchange, "LTC", "BTC")
  end

  test "Connector should track trades" do
    produce_driver(
      [
        {
          {:subscribe, "trades", "BTC", "USD"},
          success(nil)
        },
        {
          {:get_descriptor, "trades", "BTC", "USD"},
          success({Websocket, :public, {:data, "trades", "BTCUSD"}})
        }
      ],
      Websocket,
      :public
    )

    success(pid) = Connector.subscribe_trades(@exchange, "BTC", "USD")

    send(pid, {{:data, "trades", "BTCUSD"}, [[194_057_340, 1_518_428_177_185, 0.00400000, 8745.30000000], [194_057_341, 1_518_428_178_185, 0.00500000, 8746.30000000]]})

    assert_receive {Bitfinex,
                    [
                      %Trade{
                        symbol: "BITFINEX:BTC:USD",
                        uid: "194057340",
                        timestamp: ~N[2018-02-12 09:36:17.185],
                        amount: 0.004,
                        price: 8745.30000000
                      },
                      %Trade{
                        symbol: "BITFINEX:BTC:USD",
                        uid: "194057341",
                        timestamp: ~N[2018-02-12 09:36:18.185],
                        amount: 0.005,
                        price: 8746.30000000
                      }
                    ]}

    send(pid, {{:data, "trades", "BTCUSD"}, [194_057_342, 1_518_428_179_185, -0.00100000, 8742.00000000]})

    assert_receive {Bitfinex,
                    [
                      %Trade{
                        symbol: "BITFINEX:BTC:USD",
                        uid: "194057342",
                        timestamp: ~N[2018-02-12 09:36:19.185],
                        amount: -0.001,
                        price: 8742.00000000
                      }
                    ]}
  end

  test "Connector should track ticker" do
    produce_driver(
      [
        {
          {:subscribe, "ticker", "BTC", "USD"},
          success(nil)
        },
        {
          {:get_descriptor, "ticker", "BTC", "USD"},
          success({Websocket, :public, {:data, "ticker", "BTCUSD"}})
        }
      ],
      Websocket,
      :public
    )

    success(pid) = Connector.subscribe_ticker(@exchange, "BTC", "USD")

    send(pid, {{:data, "ticker", "BTCUSD"}, [9924.60000000, 32.88608832, 9925.20000000, 56.76687968, 115.80000000, 0.01180000, 9925, 70991.51188893, 10271, 9470.30000000]})

    assert_receive {Bitfinex,
                    %Ticker{
                      symbol: "BITFINEX:BTC:USD",
                      bid: 9924.60000000,
                      ask: 9925.20000000,
                      volume_24h_base: 70991.51188893
                    }}
  end
end
