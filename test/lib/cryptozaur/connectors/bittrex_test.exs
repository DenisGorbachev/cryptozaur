defmodule Cryptozaur.Connectors.BittrexTest do
  use ExUnit.Case
  import OK, only: [success: 1, failure: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Trade, Order, Level, Summary, Ticker}

  @any_secret "secret"
  @exchange "BITTREX"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "Connector should return Trade structs" do
    produce_driver(
      [
        {
          {:get_latest_trades, "DOGE", "BTC"},
          success([
            %{
              "Id" => 8_001_432,
              "TimeStamp" => "2017-09-06T13:40:52.163",
              "Quantity" => 554_166.66666667,
              "Price" => 0.00000045,
              "Total" => 0.24937500,
              "FillType" => "FILL",
              "OrderType" => "SELL"
            },
            %{
              "Id" => 8_001_433,
              "TimeStamp" => "2017-09-06T13:40:54.163",
              "Quantity" => 554_166.66666667,
              "Price" => 0.00000045,
              "Total" => 0.24937500,
              "FillType" => "FILL",
              "OrderType" => "BUY"
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    assert success([
             %Trade{
               uid: "8001432",
               symbol: "BITTREX:DOGE:BTC",
               price: 0.00000045,
               amount: -554_166.66666667,
               timestamp: ~N[2017-09-06 13:40:52.163]
             },
             %Trade{
               uid: "8001433",
               symbol: "BITTREX:DOGE:BTC",
               price: 0.00000045,
               amount: 554_166.66666667,
               timestamp: ~N[2017-09-06 13:40:54.163]
             }
           ]) == Connector.get_latest_trades(@exchange, "DOGE", "BTC")
  end

  test "Connector should place a `buy` order and return its uid" do
    key =
      produce_driver(
        [
          {
            {:buy_limit, "DOGE", "BTC", 1, 0.1},
            success(%{"uuid" => "5177a54c-7d30-4772-8c63-6d19ea971f82"})
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success("5177a54c-7d30-4772-8c63-6d19ea971f82") == Connector.place_order(@exchange, key, @any_secret, "DOGE", "BTC", 1, 0.1)
  end

  test "Connector should place a `sell` order and return its uid" do
    key =
      produce_driver(
        [
          {
            {:sell_limit, "DOGE", "BTC", 1, 0.1},
            success(%{"uuid" => "42490744-2a25-4f65-adff-8c7edfc05476"})
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success("42490744-2a25-4f65-adff-8c7edfc05476") == Connector.place_order(@exchange, key, @any_secret, "DOGE", "BTC", -1, 0.1)
  end

  test "Connector should handle an error correctly" do
    key =
      produce_driver(
        [
          {
            {:sell_limit, "BAD", "CUR", 1, 0.1},
            failure("Bad currency name")
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert failure("Bad currency name") == Connector.place_order(@exchange, key, @any_secret, "BAD", "CUR", -1, 0.1)
  end

  test "Connector should cancel order" do
    key =
      produce_driver(
        [
          {
            {:cancel, "5177a54c-7d30-4772-8c63-6d19ea971f82"},
            success(nil)
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success("5177a54c-7d30-4772-8c63-6d19ea971f82") == Connector.cancel_order(@exchange, key, @any_secret, "DOGE", "BTC", "5177a54c-7d30-4772-8c63-6d19ea971f82")
  end

  test "Connector should return Order structs" do
    key =
      produce_driver(
        [
          {
            {:get_order_history, "NEO", "BTC"},
            success([
              %{
                "Closed" => "2017-09-08T08:18:28.063",
                "Commission" => 1.6e-6,
                "Condition" => "NONE",
                "ConditionTarget" => nil,
                "Exchange" => "BTC-NEO",
                "ImmediateOrCancel" => false,
                "IsConditional" => false,
                "Limit" => 0.006421,
                "OrderType" => "LIMIT_BUY",
                "OrderUuid" => "a990106e-179a-41f4-b450-5ef8107931d8",
                "Price" => 6.42e-4,
                "PricePerUnit" => 0.00642,
                "Quantity" => 0.1,
                "QuantityRemaining" => 0.0,
                "TimeStamp" => "2017-09-08T08:18:27.89"
              }
            ])
          },
          {
            {:get_open_orders, "NEO", "BTC"},
            success([
              %{
                "Uuid" => nil,
                "OrderUuid" => "9adefb97-2802-4d16-b986-bd646fc0c2b0",
                "Exchange" => "BTC-NEO",
                "OrderType" => "LIMIT_BUY",
                "Quantity" => 0.5,
                "QuantityRemaining" => 0.4,
                "Limit" => 0.001,
                "CommissionPaid" => 3.2e-7,
                "Price" => 0.0001284,
                "PricePerUnit" => nil,
                "Opened" => "2017-09-08T08:58:56.473",
                "Closed" => nil,
                "CancelInitiated" => false,
                "ImmediateOrCancel" => false,
                "IsConditional" => false,
                "Condition" => "NONE",
                "ConditionTarget" => nil
              }
            ])
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success([
             %Order{
               uid: "9adefb97-2802-4d16-b986-bd646fc0c2b0",
               pair: "NEO:BTC",
               timestamp: ~N[2017-09-08 08:58:56.473],
               price: 0.001,
               amount_requested: 0.5,
               amount_filled: 0.1,
               status: "opened",
               base_diff: 0.1,
               quote_diff: -1.2872e-4
             },
             %Order{
               uid: "a990106e-179a-41f4-b450-5ef8107931d8",
               pair: "NEO:BTC",
               timestamp: ~N[2017-09-08 08:18:27.89],
               price: 0.006421,
               amount_requested: 0.1,
               amount_filled: 0.1,
               status: "closed",
               base_diff: 0.1,
               quote_diff: -6.436e-4
             }
           ]) == Connector.get_orders(@exchange, key, @any_secret, "NEO", "BTC")
  end

  test "Connector should return Order structs for all pairs" do
    key =
      produce_driver(
        [
          {
            {:get_order_history},
            success([
              %{
                "Closed" => "2017-09-08T08:18:28.063",
                "Commission" => 1.6e-6,
                "Condition" => "NONE",
                "ConditionTarget" => nil,
                "Exchange" => "BTC-NEO",
                "ImmediateOrCancel" => false,
                "IsConditional" => false,
                "Limit" => 0.006421,
                "OrderType" => "LIMIT_SELL",
                "OrderUuid" => "a990106e-179a-41f4-b450-5ef8107931d8",
                "Price" => 6.42e-4,
                "PricePerUnit" => 0.00642,
                "Quantity" => 0.1,
                "QuantityRemaining" => 0.0,
                "TimeStamp" => "2017-09-08T08:18:27.89"
              }
            ])
          },
          {
            {:get_open_orders},
            success([
              %{
                "Uuid" => nil,
                "OrderUuid" => "9adefb97-2802-4d16-b986-bd646fc0c2b0",
                "Exchange" => "BTC-ETH",
                "OrderType" => "LIMIT_BUY",
                "Quantity" => 0.5,
                "QuantityRemaining" => 0.4,
                "Limit" => 0.001,
                "CommissionPaid" => 3.2e-7,
                "Price" => 0.0001284,
                "PricePerUnit" => nil,
                "Opened" => "2017-09-08T08:58:56.473",
                "Closed" => nil,
                "CancelInitiated" => false,
                "ImmediateOrCancel" => false,
                "IsConditional" => false,
                "Condition" => "NONE",
                "ConditionTarget" => nil
              }
            ])
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success([
             %Order{
               uid: "9adefb97-2802-4d16-b986-bd646fc0c2b0",
               pair: "ETH:BTC",
               timestamp: ~N[2017-09-08 08:58:56.473],
               price: 0.001,
               amount_requested: 0.5,
               amount_filled: 0.1,
               status: "opened",
               base_diff: 0.1,
               quote_diff: -1.2872e-4
             },
             %Order{
               uid: "a990106e-179a-41f4-b450-5ef8107931d8",
               pair: "NEO:BTC",
               timestamp: ~N[2017-09-08 08:18:27.89],
               price: 0.006421,
               amount_requested: -0.1,
               amount_filled: -0.1,
               status: "closed",
               base_diff: -0.1,
               quote_diff: 6.404e-4
             }
           ]) == Connector.get_orders(@exchange, key, @any_secret)
  end

  test "Connector should return available balance for specified currency" do
    key =
      produce_driver(
        [
          {
            {:get_balance, "MER"},
            success(%{
              "Available" => 0.0029564,
              "Balance" => 1.0029564,
              "CryptoAddress" => "1H4RYjAeXQKZa98B5gxDV1XAvrTWNDF49m",
              "Currency" => "MER",
              "Pending" => 0.0
            })
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success(0.0029564) = Connector.get_balance(@exchange, key, @any_secret, "MER")
  end

  test "Connector should return existing deposit address" do
    key =
      produce_driver(
        [
          {
            {:get_deposit_address, "MER"},
            success(%{
              "Currency" => "MER",
              "Address" => "3P4Q6WNpbCv1eBLfLGU86a5iMTquAUUMHYN"
            })
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success("3P4Q6WNpbCv1eBLfLGU86a5iMTquAUUMHYN") = Connector.get_deposit_address(@exchange, key, @any_secret, "MER")
  end

  test "Connector should return newly created deposit address" do
    key =
      produce_driver(
        [
          {
            {:get_deposit_address, "MER"},
            failure("ADDRESS_GENERATING")
          },
          {
            {:get_deposit_address, "MER"},
            success(%{
              "Currency" => "MER",
              "Address" => "3P4Q6WNpbCv1eBLfLGU86a5iMTquAUUMHYN"
            })
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success("3P4Q6WNpbCv1eBLfLGU86a5iMTquAUUMHYN") = Connector.get_deposit_address(@exchange, key, @any_secret, "MER")
  end

  test "Connector should return an error if deposit address can't be generated" do
    key =
      produce_driver(
        [
          {
            {:get_deposit_address, "BAD_CURRENCY"},
            failure("CURRENCY_DOES_NOT_EXIST")
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert failure("CURRENCY_DOES_NOT_EXIST") == Connector.get_deposit_address(@exchange, key, @any_secret, "BAD_CURRENCY")
  end

  test "Connector should withdraw money" do
    key =
      produce_driver(
        [
          {
            {:withdraw, "MER", 2.0, "1H4RYjAeXQKZa98B5gxDV1XAvrTWNDF49m"},
            success(%{"uuid" => "3e0265cd-fa14-4960-9426-17a48b1d125f"})
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success(nil) = Connector.withdraw(@exchange, key, @any_secret, "MER", 2.0, "1H4RYjAeXQKZa98B5gxDV1XAvrTWNDF49m")
  end

  test "Connector should check if credentials provided are valid (true)" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            success([])
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success(true) = Connector.credentials_valid?(@exchange, key, @any_secret)
  end

  test "Connector should check if credentials provided are valid (false) case 1" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            failure("APIKEY_INVALID")
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success(false) = Connector.credentials_valid?(@exchange, key, @any_secret)
  end

  test "Connector should check if credentials provided are valid (false) case 2" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            failure("INVALID_SIGNATURE")
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert success(false) = Connector.credentials_valid?(@exchange, key, @any_secret)
  end

  test "Connector should properly handle errors when it checks credentials" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            failure("SOME ERROR")
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert failure(_) = Connector.credentials_valid?(@exchange, key, @any_secret)
  end

  test "Connector should check if the pair is valid (true)" do
    produce_driver(
      [
        {
          {:get_summaries},
          success([
            %{
              "Ask" => 6.398e-5,
              "BaseVolume" => 425.54098737,
              "Bid" => 6.314e-5,
              "Created" => "2017-06-06T01:22:35.727",
              "High" => 6.511e-5,
              "Last" => 6.399e-5,
              "Low" => 4.8e-5,
              "MarketName" => "BTC-DOGE",
              "OpenBuyOrders" => 700,
              "OpenSellOrders" => 3292,
              "PrevDay" => 5.123e-5,
              "TimeStamp" => "2017-12-25T10:56:52.793",
              "Volume" => 7_127_663.16860492
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    assert success(true) == Connector.pair_valid?(@exchange, "DOGE", "BTC")
  end

  test "Connector should check if the pair is valid (false)" do
    produce_driver(
      [
        {
          {:get_summaries},
          success([
            %{
              "Ask" => 6.398e-5,
              "BaseVolume" => 425.54098737,
              "Bid" => 6.314e-5,
              "Created" => "2017-06-06T01:22:35.727",
              "High" => 6.511e-5,
              "Last" => 6.399e-5,
              "Low" => 4.8e-5,
              "MarketName" => "BTC-1ST",
              "OpenBuyOrders" => 700,
              "OpenSellOrders" => 3292,
              "PrevDay" => 5.123e-5,
              "TimeStamp" => "2017-12-25T10:56:52.793",
              "Volume" => 7_127_663.16860492
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    assert success(false) == Connector.pair_valid?(@exchange, "DOGE", "BTC")
  end

  test "Connector should check if the pair is valid (forward unexpected error)" do
    produce_driver(
      [
        {
          {:get_summaries},
          failure("API_ERROR")
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    assert failure("API_ERROR") == Connector.pair_valid?(@exchange, "DOGE", "BTC")
  end

  test "Connector should return min price for a specific pair" do
    assert 1.0e-8 == Connector.get_min_price(@exchange, "ETH", "BTC")
  end

  test "Connector should handle an error correctly for `get_orders` call" do
    key =
      produce_driver(
        [
          {
            {:get_open_orders, "BAD", "CUR"},
            failure("Bad currency name")
          }
        ],
        Cryptozaur.Drivers.BittrexRest
      )

    assert failure("Bad currency name") == Connector.get_orders(@exchange, key, @any_secret, "BAD", "CUR")
  end

  test "get_tickers" do
    produce_driver(
      [
        {
          {:get_summaries},
          success([
            %{
              "Ask" => 6.398e-5,
              "BaseVolume" => 425.54098737,
              "Bid" => 6.314e-5,
              "Created" => "2017-06-06T01:22:35.727",
              "High" => 6.511e-5,
              "Last" => 6.399e-5,
              "Low" => 4.8e-5,
              "MarketName" => "BTC-1ST",
              "OpenBuyOrders" => 700,
              "OpenSellOrders" => 3292,
              "PrevDay" => 5.123e-5,
              "TimeStamp" => "2017-12-25T10:56:52.793",
              "Volume" => 7_127_663.16860492
            },
            %{
              "Ask" => 1.74e-6,
              "BaseVolume" => 141.7306921,
              "Bid" => 1.72e-6,
              "Created" => "2016-05-16T06:44:15.287",
              "High" => 2.0e-6,
              "Last" => 1.72e-6,
              "Low" => 1.31e-6,
              "MarketName" => "BTC-2GIVE",
              "OpenBuyOrders" => 451,
              "OpenSellOrders" => 838,
              "PrevDay" => 1.39e-6,
              "TimeStamp" => "2017-12-25T10:56:40.373",
              "Volume" => 83_831_534.78222822
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    assert success([
             %Ticker{
               symbol: "BITTREX:1ST:BTC",
               bid: 6.314e-5,
               ask: 6.398e-5,
               volume_24h_base: 7_127_663.16860492,
               volume_24h_quote: 425.54098737
             },
             %Ticker{
               symbol: "BITTREX:2GIVE:BTC",
               bid: 1.72e-6,
               ask: 1.74e-6,
               volume_24h_base: 83_831_534.78222822,
               volume_24h_quote: 141.7306921
             }
           ]) == Connector.get_tickers("BITTREX")
  end

  test "get_ticker" do
    produce_driver(
      [
        {
          {:get_summaries},
          success([
            %{
              "Ask" => 6.398e-5,
              "BaseVolume" => 425.54098737,
              "Bid" => 6.314e-5,
              "Created" => "2017-06-06T01:22:35.727",
              "High" => 6.511e-5,
              "Last" => 6.399e-5,
              "Low" => 4.8e-5,
              "MarketName" => "BTC-1ST",
              "OpenBuyOrders" => 700,
              "OpenSellOrders" => 3292,
              "PrevDay" => 5.123e-5,
              "TimeStamp" => "2017-12-25T10:56:52.793",
              "Volume" => 7_127_663.16860492
            },
            %{
              "Ask" => 1.74e-6,
              "BaseVolume" => 141.7306921,
              "Bid" => 1.72e-6,
              "Created" => "2016-05-16T06:44:15.287",
              "High" => 2.0e-6,
              "Last" => 1.72e-6,
              "Low" => 1.31e-6,
              "MarketName" => "BTC-2GIVE",
              "OpenBuyOrders" => 451,
              "OpenSellOrders" => 838,
              "PrevDay" => 1.39e-6,
              "TimeStamp" => "2017-12-25T10:56:40.373",
              "Volume" => 83_831_534.78222822
            }
          ])
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    assert success(%Ticker{
             symbol: "BITTREX:1ST:BTC",
             bid: 6.314e-5,
             ask: 6.398e-5,
             volume_24h_base: 7_127_663.16860492,
             volume_24h_quote: 425.54098737
           }) == Connector.get_ticker("BITTREX", "1ST", "BTC")
  end

  test "Connector should return current order book" do
    produce_driver(
      [
        {
          {:get_order_book, "DOGE", "BTC", "both"},
          success(%{
            "buy" => [
              %{"Quantity" => 71_304_472.3220168, "Rate" => 4.1e-7},
              %{"Quantity" => 71_304_572.3220168, "Rate" => 4.0e-7}
            ],
            "sell" => [
              %{"Quantity" => 71_304_372.3220168, "Rate" => 4.2e-7}
            ]
          })
        }
      ],
      Cryptozaur.Drivers.BittrexRest,
      :public
    )

    # TODO: this code is unstable (e.g. timestamp var is assigned on one second, but request happens on next second)
    timestamp = Cryptozaur.Utils.now()

    assert success({
             [
               %Level{price: 4.1e-7, amount: 71_304_472.3220168, timestamp: timestamp, symbol: "BITTREX:DOGE:BTC"},
               %Level{price: 4.0e-7, amount: 71_304_572.3220168, timestamp: timestamp, symbol: "BITTREX:DOGE:BTC"}
             ],
             [
               %Level{price: 4.2e-7, amount: -71_304_372.3220168, timestamp: timestamp, symbol: "BITTREX:DOGE:BTC"}
             ]
           }) == Connector.get_levels("BITTREX", "DOGE", "BTC")
  end

  test "should validate order (true)" do
    assert success(nil) == Connector.validate_order(@exchange, "LTC", "BTC", 1.0, 60.0)
  end

  test "should validate order (false): dust trade" do
    assert failure([%{key: "amount", message: "Minimum order amount at specified price is 0.50000000 LTC"}]) == Connector.validate_order(@exchange, "LTC", "BTC", 0.001, 0.002)
  end

  test "should get link" do
    assert "https://bittrex.com/Market/Index?MarketName=BTC-LTC" == Connector.get_link(@exchange, "LTC", "BTC")
  end
end
