defmodule Cryptozaur.Connectors.PoloniexTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Connector, Metronome}
  alias Cryptozaur.Model.{Trade}

  # @any_secret "secret"
  @exchange "POLONIEX"

  setup do
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "Connector should return Trade structs" do
    produce_driver(
      [
        {
          {:get_trade_history, "DOGE", "BTC", ~N[2017-09-06 15:00:00], ~N[2017-09-06 18:00:00]},
          success([
            %{
              "globalTradeID" => 226_745_348,
              "tradeID" => 3_589_405,
              "date" => "2017-09-06 17:40:36",
              "type" => "sell",
              "rate" => "0.00000044",
              "amount" => "140249.04009475",
              "total" => "0.06170957"
            }
          ])
        }
      ],
      Cryptozaur.Drivers.PoloniexRest,
      :public
    )

    assert success([
             %Trade{
               uid: "226745348",
               symbol: "POLONIEX:DOGE:BTC",
               price: 0.00000044,
               amount: -140_249.04009475,
               timestamp: ~N[2017-09-06 17:40:36]
             }
           ]) == Connector.get_trades(@exchange, "DOGE", "BTC", ~N[2017-09-06 15:00:00], ~N[2017-09-06 18:00:00])
  end
end

# defmodule Poloniex.Test do
#  use ExUnit.Case, async: false
#
#  import Mock
#
#  setup_all do
#    %{
#      account: %Accounts{exchange: "POLONIEX", pairs: ["BTC:USDT", "LTC:BTC"], key: "test_key", secret: "test_secret", strategy: "STRATEGY"}
#    }
#  end
#
#  test "Poloniex get_balances", %{account: account} do
#    stub = {:ok, [{"LTC", 0.0}, {"BTC", 0.00099750}]}
#
#    with_mock Cryptozaur.Drivers.Poloniex, [get_balances: fn(_, _) -> stub end] do
#      {:ok, balances} = CryptozaurConnectors.Poloniex.get_balances(account)
#      %{"LTC" => 0.0, "BTC" => 0.00099750} = balances
#    end
#  end
#
#  test "Poloniex place_order", %{account: account} do
#    stub = {:ok, %{"orderNumber" => "79126187728", "resultingTrades" => []}}
#    with_mock Cryptozaur.Drivers.Poloniex, [place_order: fn(_, _, _, _, _, _, _) -> stub end] do
#      {:ok, orderNumber} = CryptozaurConnectors.Poloniex.place_order(account, "BTC", "USDT", 2500, 1)
#      assert orderNumber == "79126187728"
#    end
#  end
#
#  test "Poloniex move_order", %{account: account} do
#    stub = {:ok, %{"orderNumber" => "65338980732", "resultingTrades" => %{"BTC_XRP" => []}, "success" => 1}}
#    with_mock Cryptozaur.Drivers.Poloniex, [move_order: fn(_, _, _, _, _, _) -> stub end] do
#      {:ok, orderNumber} = CryptozaurConnectors.Poloniex.move_order(account, "79126187728", 2500, 1)
#      assert orderNumber == "65338980732"
#    end
#  end
#
#  test "Poloniex cancel_order successfully", %{account: account} do
#    stub = {:ok, %{"amount" => "0.00100000", "message" => "Order #79126187728 canceled.", "success" => 1}}
#    with_mock Cryptozaur.Drivers.Poloniex, [cancel_order: fn(_, _, _, _) -> stub end] do
#      {:ok, nil} = CryptozaurConnectors.Poloniex.cancel_order(account, "79126187728")
#    end
#  end
#
#  test "Poloniex cancel_order should throw an exception because the order doesn't exist'", %{account: account} do
#    stub = {:error, "Invalid order number, or you are not the person who placed the order."}
#    with_mock Cryptozaur.Drivers.Poloniex, [cancel_order: fn(_, _, _, _) -> stub end] do
#      {:error, reason} = CryptozaurConnectors.Poloniex.cancel_order(account, "79126187728")
#      assert reason == "Invalid order number, or you are not the person who placed the order."
#    end
#  end
#
#  test "Poloniex get_orders should return open orders for BTC_USDT pair", %{account: account} do
#    stub = {:ok, [%{"amount" => "0.00100000", "date" => "2017-07-19 06:26:19", "margin" => 0,
#                          "orderNumber" => "79268263510", "rate" => "1000.00000000",
#                          "startingAmount" => "0.00100000", "total" => "1.00000000", "type" => "buy"}]}
#
#    with_mock Cryptozaur.Drivers.Poloniex, [get_orders: fn(_, _, _, _, _) -> stub end] do
#      {:ok, orders} = CryptozaurConnectors.Poloniex.get_orders(account, "BTC", "USDT")
#
#      [%{price: 1000.0, amount: 0.001, orderNumber: "79268263510"}] = orders
#    end
#  end
#
#  test "Poloniex get_orders should return no orders for LTC_BTC pair", %{account: account} do
#    stub = {:ok, []}
#
#    with_mock Cryptozaur.Drivers.Poloniex, [get_orders: fn(_, _, _, _, _) -> stub end] do
#      {:ok, orders} = CryptozaurConnectors.Poloniex.get_orders(account, "BTC", "USDT")
#
#      [] = orders
#    end
#  end
# end
