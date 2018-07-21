defmodule Cryptozaur.Connectors.KucoinTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Order, Ticker, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_balance" do
    key =
      produce_driver(
        [
          {
            {:get_balance, "ETH"},
            success(%{
              "balance" => 0.9953,
              "balanceStr" => "0.9953",
              "coinType" => "ETH",
              "freezeBalance" => 0.0,
              "freezeBalanceStr" => "0.0"
            })
          }
        ],
        Cryptozaur.Drivers.KucoinRest
      )

    assert success(%Balance{amount: 0.9953, currency: "ETH"}) = Connector.get_balance("KUCOIN", key, "secret", "ETH")
  end

  test "get_balances" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            success(%{
              "datas" => [
                %{
                  "balance" => 0.9953,
                  "balanceStr" => "0.9953",
                  "coinType" => "ETH",
                  "freezeBalance" => 0.0,
                  "freezeBalanceStr" => "0.0"
                },
                %{
                  "balance" => 0.0,
                  "balanceStr" => "0.0",
                  "coinType" => "BHC",
                  "freezeBalance" => 0.0,
                  "freezeBalanceStr" => "0.0"
                }
              ]
            })
          }
        ],
        Cryptozaur.Drivers.KucoinRest
      )

    assert success([
             %Balance{amount: 0.9953, currency: "ETH"},
             %Balance{amount: 0.0, currency: "BHC"}
           ]) = Connector.get_balances("KUCOIN", key, "secret")
  end

  test "get_orders" do
    key =
      produce_driver(
        [
          {
            {:get_open_orders},
            success(%{
              "BUY" => [
                %{
                  "coinType" => "KCS",
                  "coinTypePair" => "ETH",
                  "createdAt" => 1_516_998_699_000,
                  "dealAmount" => 0.0,
                  "direction" => "BUY",
                  "oid" => "5a6b902a5e39302701af70f8",
                  "pendingAmount" => 1.0,
                  "price" => 1.0e-5,
                  "updatedAt" => 1_516_998_699_000,
                  "userOid" => nil
                }
              ],
              "SELL" => []
            })
          },
          {
            {:get_closed_orders},
            success(%{
              "datas" => [
                %{
                  "amount" => 2.00000000,
                  "coinType" => "TNC",
                  "coinTypePair" => "ETH",
                  "createdAt" => 1_517_199_222_000,
                  "dealDirection" => "SELL",
                  "dealPrice" => 0.00030300,
                  "dealValue" => 0.00060600,
                  "direction" => "BUY",
                  "fee" => 0.00200000,
                  "feeRate" => 0.00100000,
                  "oid" => "5a6e9f7673fb6f11d627adeb",
                  "orderOid" => "5a6e9f6b87a12d4439beaa2a"
                },
                %{
                  "amount" => 1.00000000,
                  "coinType" => "TNC",
                  "coinTypePair" => "ETH",
                  "createdAt" => 1_517_199_123_000,
                  "dealDirection" => "BUY",
                  "dealPrice" => 0.00031000,
                  "dealValue" => 0.00031000,
                  "direction" => "BUY",
                  "fee" => 0.00100000,
                  "feeRate" => 0.00100000,
                  "oid" => "5a6e9f1373fb6f11d627adcf",
                  "orderOid" => "5a6e9f1273fb6f12b0588de5"
                }
              ]
            })
          }
        ],
        Cryptozaur.Drivers.KucoinRest
      )

    # TODO: check all properties of each order (amount_requested, amount_filled, total)
    assert success([
             %Order{
               uid: "5a6b902a5e39302701af70f8",
               pair: "KCS:ETH",
               price: 1.0e-5,
               amount_requested: 1.0,
               amount_filled: 0.0,
               base_diff: 0.0,
               quote_diff: 0.0
             },
             %Order{
               uid: "5a6e9f7673fb6f11d627adeb",
               pair: "TNC:ETH",
               price: 0.00030300,
               amount_filled: 2.0,
               base_diff: 1.998,
               quote_diff: -0.000606
             },
             %Order{
               uid: "5a6e9f1373fb6f11d627adcf",
               pair: "TNC:ETH",
               price: 0.00031000,
               amount_filled: 1.0,
               base_diff: 0.999,
               quote_diff: -0.00031
             }
           ]) = Connector.get_orders("KUCOIN", key, "secret")
  end

  test "place_order (buy)" do
    key =
      produce_driver(
        [
          {
            {:create_order, "KCS-ETH", 1, 0.00001, "BUY"},
            success(%{"orderOid" => "5a644e9a5e39307a633db6c1"})
          }
        ],
        Cryptozaur.Drivers.KucoinRest
      )

    assert success("5a644e9a5e39307a633db6c1") == Connector.place_order("KUCOIN", key, "secret", "KCS", "ETH", 1, 0.00001)
  end

  test "place_order (sell)" do
    key =
      produce_driver(
        [
          {
            {:create_order, "KCS-ETH", 1, 1000, "SELL"},
            success(%{"orderOid" => "5a644e9a5e39307a633db6c1"})
          }
        ],
        Cryptozaur.Drivers.KucoinRest
      )

    assert success("5a644e9a5e39307a633db6c1") == Connector.place_order("KUCOIN", key, "secret", "KCS", "ETH", -1, 1000)
  end

  test "cancel_order" do
    key =
      produce_driver(
        [
          {
            {:cancel_order, "KCS-ETH", "5a644e9a5e39307a633db6c1", "BUY"},
            success(true)
          }
        ],
        Cryptozaur.Drivers.KucoinRest
      )

    assert success(true) == Connector.cancel_order("KUCOIN", key, "secret", "KCS", "ETH", "5a644e9a5e39307a633db6c1", "BUY")
  end

  test "get_tickers" do
    produce_driver(
      [
        {
          {:get_tickers},
          success([
            %{
              "buy" => 0.00123223,
              "change" => 4.5424e-4,
              "changeRate" => 0.5839,
              "coinType" => "KCS",
              "coinTypePair" => "BTC",
              "datetime" => 1_515_343_594_000,
              "feeRate" => 0.001,
              "high" => 0.00123223,
              "lastDealPrice" => 0.00123223,
              "low" => 6.4804e-4,
              "sell" => 0.00123456,
              "sort" => 0,
              "symbol" => "KCS-BTC",
              "trading" => true,
              "vol" => 2_323_140.3482,
              "volValue" => 2045.67061427
            },
            %{
              "buy" => 0.018084,
              "change" => 0.003904,
              "changeRate" => 0.2753,
              "coinType" => "KCS",
              "coinTypePair" => "ETH",
              "datetime" => 1_515_343_594_000,
              "feeRate" => 0.001,
              "high" => 0.0183,
              "lastDealPrice" => 0.018084,
              "low" => 0.011,
              "sell" => 0.01829,
              "sort" => 0,
              "symbol" => "KCS-ETH",
              "trading" => true,
              "vol" => 407_692.3637,
              "volValue" => 5870.37318604
            }
          ])
        }
      ],
      Cryptozaur.Drivers.KucoinRest,
      :public
    )

    assert success([
             %Ticker{
               symbol: "KUCOIN:KCS:BTC",
               bid: 0.00123223,
               ask: 0.00123456,
               volume_24h_base: 2_323_140.3482,
               volume_24h_quote: 2045.67061427
             },
             %Ticker{
               symbol: "KUCOIN:KCS:ETH",
               bid: 0.018084,
               ask: 0.01829,
               volume_24h_base: 407_692.3637,
               volume_24h_quote: 5870.37318604
             }
           ]) == Connector.get_tickers("KUCOIN")
  end

  test "Connector should return tickers" do
    produce_driver(
      [
        {
          {:get_tickers},
          success([
            %{
              "buy" => 0.00123223,
              "change" => 4.5424e-4,
              "changeRate" => 0.5839,
              "coinType" => "KCS",
              "coinTypePair" => "BTC",
              "datetime" => 1_515_343_594_000,
              "feeRate" => 0.001,
              "high" => 0.00123223,
              "lastDealPrice" => 0.00123223,
              "low" => 6.4804e-4,
              "sell" => 0.00123456,
              "sort" => 0,
              "symbol" => "KCS-BTC",
              "trading" => true,
              "vol" => 2_323_140.3482,
              "volValue" => 2045.67061427
            }
          ])
        }
      ],
      Cryptozaur.Drivers.KucoinRest,
      :public
    )

    assert Connector.get_ticker("KUCOIN", "KCS", "BTC") ==
             success(%Ticker{
               symbol: "KUCOIN:KCS:BTC",
               bid: 0.00123223,
               ask: 0.00123456,
               volume_24h_base: 2_323_140.3482,
               volume_24h_quote: 2045.67061427
             })
  end
end
