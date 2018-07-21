defmodule Cryptozaur.Drivers.PoloniexRest.RestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1]

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :poloniex, key: "", secret: "")

    {:ok, driver} = Cryptozaur.Drivers.PoloniexRest.start_link(Enum.into(credentials, %{}))

    %{driver: driver}
  end

  test "get_trade_history should return trades happended on a specified time range", %{driver: driver} do
    use_cassette "poloniex/get_trade_history" do
      success([trade | _rest]) = Cryptozaur.Drivers.PoloniexRest.get_trade_history(driver, "DOGE", "BTC", ~N[2017-09-06T13:40:52], ~N[2017-09-06T17:40:52])

      assert %{
               "globalTradeID" => 226_745_348,
               "tradeID" => 3_589_405,
               "date" => "2017-09-06 17:40:36",
               "type" => "sell",
               "rate" => "0.00000044",
               "amount" => "140249.04009475",
               "total" => "0.06170957"
             } == trade
    end
  end

  test "get_trade_history should return trades on a specified time range inclusively", %{driver: driver} do
    use_cassette "poloniex/get_trade_history_inclusive", match_requests_on: [:query] do
      success(trades_upper_border) = Cryptozaur.Drivers.PoloniexRest.get_trade_history(driver, "DOGE", "BTC", ~N[2014-09-23 19:03:29], ~N[2014-09-23 19:04:29])
      success(trades_lower_border) = Cryptozaur.Drivers.PoloniexRest.get_trade_history(driver, "DOGE", "BTC", ~N[2014-09-23 19:04:29], ~N[2014-09-23 19:05:29])

      assert Enum.any?(trades_upper_border, &(&1["globalTradeID"] == 2_133_807))
      assert Enum.any?(trades_lower_border, &(&1["globalTradeID"] == 2_133_807))
    end
  end

  #  test "Poloniex get_balances", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_get_balances" do
  #      balances = Cryptozaur.Drivers.PoloniexRest.get_balances(key, secret) ~>> Map.new
  #      %{"LTC" => 0.0, "BTC" => 0.00099750} = balances
  #    end
  #  end
  #
  #  test "Poloniex place_order", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_place_order" do
  #      {:ok, result} = Cryptozaur.Drivers.PoloniexRest.place_order(key, secret, "BTC", "USDT", 1000, 0.001, postOnly: 1)
  #      %{"orderNumber" => "79126187728", "resultingTrades" => []} = result
  #    end
  #  end
  #
  #  test "Poloniex move_order", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_move_order" do
  #      {:ok, result} = Cryptozaur.Drivers.PoloniexRest.move_order(key, secret, "65279377395", 0.00007500, 10)
  #      %{"orderNumber" => "65338980732", "resultingTrades" => %{"BTC_XRP" => []}, "success" => 1} = result
  #    end
  #  end
  #
  #  test "Poloniex cancel_order successfully", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_cancel_order" do
  #      {:ok, result} = Cryptozaur.Drivers.PoloniexRest.cancel_order(key, secret, "79126187728")
  #      %{"amount" => "0.00100000", "message" => "Order #79126187728 canceled.", "success" => 1} = result
  #    end
  #  end
  #
  #  test "Poloniex cancel_order should return an error because the order doesn't exist", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_cancel_order_bad" do
  #      {:error, result} = Cryptozaur.Drivers.PoloniexRest.cancel_order(key, secret, "79126187728")
  #      assert result == "Invalid order number, or you are not the person who placed the order."
  #    end
  #  end
  #
  #  test "Poloniex get_orders should return open orders for BTC_USDT pair", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_get_orders" do
  #      {:ok, orders} = Cryptozaur.Drivers.PoloniexRest.get_orders(key, secret, "BTC", "USDT")
  #      [%{"amount" => "0.00100000", "date" => "2017-07-19 06:26:19", "margin" => 0,
  #         "orderNumber" => "79268263510", "rate" => "1000.00000000",
  #         "startingAmount" => "0.00100000", "total" => "1.00000000", "type" => "buy"}] = orders
  #    end
  #  end
  #
  #  test "Poloniex get_orders should return no orders for LTC_BTC pair", %{key: key, secret: secret} do
  #    use_cassette "Poloniex_get_orders_no_orders" do
  #      {:ok, orders} = Cryptozaur.Drivers.PoloniexRest.get_orders(key, secret, "LTC", "BTC")
  #      assert [] = orders
  #    end
  #  end
end
