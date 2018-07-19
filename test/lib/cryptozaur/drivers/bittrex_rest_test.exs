defmodule Cryptozaur.Drivers.BittrexRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :bittrex, %{key: "", secret: ""})

    {:ok, driver} = Cryptozaur.Drivers.BittrexRest.start_link(credentials)

    %{driver: driver}
  end

  test "get_latest_trades should return a bucket of trades", %{driver: driver} do
    use_cassette "bittrex/get_latest_trades" do
      {:ok, trades} = Cryptozaur.Drivers.BittrexRest.get_latest_trades(driver, "DOGE", "BTC")

      [
        %{
          "Id" => 8_001_432,
          "TimeStamp" => "2017-09-06T13:40:52.163",
          "Quantity" => 554_166.66666667,
          "Price" => 0.00000045,
          "Total" => 0.24937500,
          "FillType" => "FILL",
          "OrderType" => "BUY"
        }
        | _
      ] = trades
    end
  end

  test "should detect an error", %{driver: driver} do
    use_cassette "bittrex/error" do
      {:error, "INVALID_MARKET"} = Cryptozaur.Drivers.BittrexRest.get_latest_trades(driver, "BTC", "BAD")
    end
  end

  test "should successfully send an authenticated request", %{driver: driver} do
    use_cassette "bittrex/auth_success" do
      # any private request is acceptable
      {:ok, _} = Cryptozaur.Drivers.BittrexRest.get_open_orders(driver)
    end
  end

  test "should properly handle a `bad api key` response", %{driver: _driver} do
    use_cassette "bittrex/auth_bad_key" do
      bad_credentials = %{key: "XXX", secret: "YYY"}
      {:ok, driver} = Cryptozaur.Drivers.BittrexRest.start_link(bad_credentials)
      {:error, "APIKEY_INVALID"} = Cryptozaur.Drivers.BittrexRest.get_open_orders(driver)
    end
  end

  test "should properly handle a `bad secret` response", %{driver: _driver} do
    use_cassette "bittrex/auth_bad_secret" do
      bad_credentials = %{key: "319fabede47a40b2819525d8b7c0d1ce", secret: "YYY"}
      {:ok, driver} = Cryptozaur.Drivers.BittrexRest.start_link(bad_credentials)
      {:error, "INVALID_SIGNATURE"} = Cryptozaur.Drivers.BittrexRest.get_open_orders(driver)
    end
  end

  test "get_order_history should return some completed orders", %{driver: driver} do
    use_cassette "bittrex/get_order_history" do
      {:ok,
       [
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
       ]} = Cryptozaur.Drivers.BittrexRest.get_order_history(driver)
    end
  end

  test "get_order_history should return completed orders for specified pair", %{driver: driver} do
    use_cassette "bittrex/get_order_history_pair" do
      {:ok,
       [
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
       ]} = Cryptozaur.Drivers.BittrexRest.get_order_history(driver, "NEO", "BTC")
    end
  end

  test "get_order should return information about the specified order", %{driver: driver} do
    use_cassette "bittrex/get_order" do
      {:ok,
       %{
         "AccountId" => nil,
         "CancelInitiated" => false,
         "Closed" => "2017-09-08T08:18:28.063",
         "CommissionPaid" => 1.6e-6,
         "CommissionReserveRemaining" => 0.0,
         "CommissionReserved" => 1.6e-6,
         "Condition" => "NONE",
         "ConditionTarget" => nil,
         "Exchange" => "BTC-NEO",
         "ImmediateOrCancel" => false,
         "IsConditional" => false,
         "IsOpen" => false,
         "Limit" => 0.006421,
         "Opened" => "2017-09-08T08:18:27.89",
         "OrderUuid" => "a990106e-179a-41f4-b450-5ef8107931d8",
         "Price" => 6.42e-4,
         "PricePerUnit" => 0.00642,
         "Quantity" => 0.1,
         "QuantityRemaining" => 0.0,
         "ReserveRemaining" => 6.42e-4,
         "Reserved" => 6.421e-4,
         "Sentinel" => "083e6a62-281f-4892-9e1e-fecfb92385d5",
         "Type" => "LIMIT_BUY"
       }} = Cryptozaur.Drivers.BittrexRest.get_order(driver, "a990106e-179a-41f4-b450-5ef8107931d8")
    end
  end

  test "get_balances should return information about user balances", %{driver: driver} do
    use_cassette "bittrex/get_balances" do
      {:ok,
       [
         %{
           "Available" => 0.0029564,
           "Balance" => 0.0029564,
           "CryptoAddress" => "1H4RYjAeXQKZa98B5gxDV1XAvrTWNDF49m",
           "Currency" => "BTC",
           "Pending" => 0.0
         }
         | _
       ]} = Cryptozaur.Drivers.BittrexRest.get_balances(driver)
    end
  end

  test "get_balance should return information about balance of the specified currency", %{driver: driver} do
    use_cassette "bittrex/get_balance" do
      {:ok,
       %{
         "Available" => 0.0029564,
         "Balance" => 0.0029564,
         "CryptoAddress" => "1H4RYjAeXQKZa98B5gxDV1XAvrTWNDF49m",
         "Currency" => "BTC",
         "Pending" => 0.0
       }} = Cryptozaur.Drivers.BittrexRest.get_balance(driver, "BTC")
    end
  end

  test "get_open_orders should return information all open orders", %{driver: driver} do
    use_cassette "bittrex/get_open_orders_all" do
      {:ok, []} = Cryptozaur.Drivers.BittrexRest.get_open_orders(driver)
    end
  end

  test "get_open_orders should return information open orders for specific pair", %{driver: driver} do
    use_cassette "bittrex/get_open_orders" do
      {:ok,
       [
         %{
           "CancelInitiated" => false,
           "Closed" => nil,
           "CommissionPaid" => 0.0,
           "Condition" => "NONE",
           "ConditionTarget" => nil,
           "Exchange" => "BTC-OMG",
           "ImmediateOrCancel" => false,
           "IsConditional" => false,
           "Limit" => 0.001,
           "Opened" => "2017-09-08T08:58:56.473",
           "OrderType" => "LIMIT_BUY",
           "OrderUuid" => "9adefb97-2802-4d16-b986-bd646fc0c2b0",
           "Price" => 0.0,
           "PricePerUnit" => nil,
           "Quantity" => 0.5,
           "QuantityRemaining" => 0.5,
           "Uuid" => nil
         }
       ]} = Cryptozaur.Drivers.BittrexRest.get_open_orders(driver, "OMG", "BTC")
    end
  end

  test "sell_limit should place order with specified parameters and return its UUID", %{driver: driver} do
    use_cassette "bittrex/sell_limit" do
      {:ok, %{"uuid" => "42490744-2a25-4f65-adff-8c7edfc05476"}} = Cryptozaur.Drivers.BittrexRest.sell_limit(driver, "NEO", "BTC", 0.05, 0.1)
    end
  end

  test "sell_limit should return an error because of negative price", %{driver: driver} do
    use_cassette "bittrex/sell_limit_negative_price" do
      {:error, "RATE_INVALID"} = Cryptozaur.Drivers.BittrexRest.sell_limit(driver, "NEO", "BTC", 0.05, -1)
    end
  end

  test "sell_limit should return an error because of huge price", %{driver: driver} do
    use_cassette "bittrex/sell_limit_huge_price" do
      {:error, "ZERO_OR_NEGATIVE_NOT_ALLOWED"} = Cryptozaur.Drivers.BittrexRest.sell_limit(driver, "NEO", "BTC", 0.05, 10)
    end
  end

  test "sell_limit should return an error because of negative amount", %{driver: driver} do
    use_cassette "bittrex/sell_limit_negative_amount" do
      {:error, "QUANTITY_INVALID"} = Cryptozaur.Drivers.BittrexRest.sell_limit(driver, "NEO", "BTC", -0.05, 1)
    end
  end

  test "sell_limit should return an error because of insuccficient funds", %{driver: driver} do
    use_cassette "bittrex/sell_limit_insufficient_funds" do
      {:error, "INSUFFICIENT_FUNDS"} = Cryptozaur.Drivers.BittrexRest.sell_limit(driver, "NEO", "BTC", 10, 0.1)
    end
  end

  test "buy_limit should place order with specified parameters and return its UUID", %{driver: driver} do
    use_cassette "bittrex/buy_limit" do
      {:ok, %{"uuid" => "5177a54c-7d30-4772-8c63-6d19ea971f82"}} = Cryptozaur.Drivers.BittrexRest.buy_limit(driver, "NEO", "BTC", 5, 0.0001)
    end
  end

  test "buy_limit should return an error because of low volume", %{driver: driver} do
    use_cassette "bittrex/buy_limit_low_volume" do
      {:error, "DUST_TRADE_DISALLOWED_MIN_VALUE_50K_SAT"} = Cryptozaur.Drivers.BittrexRest.buy_limit(driver, "NEO", "BTC", 1, 0.0001)
    end
  end

  test "buy_limit should return an error because of insuccficient funds", %{driver: driver} do
    use_cassette "bittrex/buy_limit_insufficient_funds" do
      {:error, "INSUFFICIENT_FUNDS"} = Cryptozaur.Drivers.BittrexRest.buy_limit(driver, "NEO", "BTC", 100, 0.0001)
    end
  end

  test "cancel_limit should cancel an existing order", %{driver: driver} do
    use_cassette "bittrex/cancel" do
      {:ok, nil} = Cryptozaur.Drivers.BittrexRest.cancel(driver, "5177a54c-7d30-4772-8c63-6d19ea971f82")
    end
  end

  test "cancel_limit should return an error because the order doesn't exist", %{driver: driver} do
    use_cassette "bittrex/cancel_not_exist" do
      {:error, "UUID_INVALID"} = Cryptozaur.Drivers.BittrexRest.cancel(driver, "5177a54c-7d30-4772-8c63-0000000000")
    end
  end

  test "get_summaries should return summary for each pair", %{driver: driver} do
    use_cassette "bittrex/get_summaries" do
      {
        :ok,
        [
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
          | _
        ]
      } = Cryptozaur.Drivers.BittrexRest.get_summaries(driver)
    end
  end

  test "get_order_book should return order book for specified currency", %{driver: driver} do
    use_cassette "bittrex/order_book" do
      {:ok,
       %{
         "buy" => [
           %{"Quantity" => 71_304_372.3220168, "Rate" => 4.2e-7}
           | _
         ],
         "sell" => [
           %{"Quantity" => 6_509_580.51255401, "Rate" => 4.3e-7}
           | _
         ]
       }} = Cryptozaur.Drivers.BittrexRest.get_order_book(driver, "DOGE", "BTC")
    end
  end

  test "get_order_book should return sell order from order book for specified currency", %{driver: driver} do
    use_cassette "bittrex/order_book_type" do
      {:ok, [%{"Quantity" => 6_498_664.91507249, "Rate" => 4.3e-7} | _]} = Cryptozaur.Drivers.BittrexRest.get_order_book(driver, "DOGE", "BTC", "sell")
    end
  end

  test "get_order_book should return an error when pair is incorrect", %{driver: driver} do
    use_cassette "bittrex/order_book_bad_pair" do
      {:error, "INVALID_MARKET"} = Cryptozaur.Drivers.BittrexRest.get_order_book(driver, "BTC", "USD")
    end
  end

  test "get_deposit_address should return a deposit address for specified currency", %{driver: driver} do
    use_cassette "bittrex/get_deposit_address" do
      {:ok,
       %{
         "Currency" => "MER",
         "Address" => "3P4Q6WNpbCv1eBLfLGU86a5iMTquAUUMHYN"
       }} = Cryptozaur.Drivers.BittrexRest.get_deposit_address(driver, "MER")
    end
  end

  test "get_deposit_address should return an error when deposit address is being generated", %{driver: driver} do
    use_cassette "bittrex/get_deposit_address_generation" do
      {:error, "ADDRESS_GENERATING"} = Cryptozaur.Drivers.BittrexRest.get_deposit_address(driver, "MER")
    end
  end

  test "get_deposit_address should return an error when currency is invalid", %{driver: driver} do
    use_cassette "bittrex/get_deposit_address_invalid_currency" do
      {:error, "CURRENCY_DOES_NOT_EXIST"} = Cryptozaur.Drivers.BittrexRest.get_deposit_address(driver, "INVALID_CURRENCY")
    end
  end

  test "withdraw should send money to destination address", %{driver: driver} do
    use_cassette "bittrex/withdraw" do
      assert {:ok, %{"uuid" => "3e0265cd-fa14-4960-9426-17a48b1d125f"}} == Cryptozaur.Drivers.BittrexRest.withdraw(driver, "BCC", 0.005, "1MbLs7SnPUEkQpULzJEfw3jmFaRDBcy24E")
    end
  end

  test "withdraw should return an error when currency is invalid", %{driver: driver} do
    use_cassette "bittrex/withdraw_invalid_currency" do
      assert {:error, "INVALID_CURRENCY"} == Cryptozaur.Drivers.BittrexRest.withdraw(driver, "BAD_CURRENCY", 0.005, "1MbLs7SnPUEkQpULzJEfw3jmFaRDBcy24E")
    end
  end

  test "withdraw should return an error when amount is too small", %{driver: driver} do
    use_cassette "bittrex/withdraw_small_amount" do
      assert {:error, "WITHDRAWAL_TOO_SMALL"} == Cryptozaur.Drivers.BittrexRest.withdraw(driver, "BCC", 0.001, "1MbLs7SnPUEkQpULzJEfw3jmFaRDBcy24E")
    end
  end

  #  test "get_depth should return total buys and sells for a given symbol", %{driver: driver} do
  #    use_cassette "bittrex/depth" do
  #      {:ok, %{"buys" => 6498664.91507249, "sells" => 6498664.91507249}} = Cryptozaur.Drivers.BittrexRest.get_depth(driver, "EDG", "BTC")
  #    end
  #  end
  #
  #  test "get_depth should return an error when pair is incorrect", %{driver: driver} do
  #    use_cassette "bittrex/depth_bad_pair" do
  #      {:error, "INVALID_MARKET"} = Cryptozaur.Drivers.BittrexRest.get_depth(driver, "BAD", "CUR")
  #    end
  #  end
end
