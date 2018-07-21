defmodule Cryptozaur.Drivers.YobitRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :yobit, key: "", secret: "")

    {:ok, driver} = Cryptozaur.Drivers.YobitRest.start_link(Enum.into(credentials, %{}))

    %{driver: driver}
  end

  #  test "get_latest_trades should return a bucket of trades", %{driver: driver} do
  #    use_cassette "yobit/get_latest_trades" do
  #      {:ok, trades} = Cryptozaur.Drivers.YobitRest.get_latest_trades(driver, "DOGE", "BTC")
  #      [
  #        %{
  #          "Id" => 8001432,
  #          "TimeStamp" => "2017-09-06T13:40:52.163",
  #          "Quantity" => 554166.66666667,
  #          "Price" => 0.00000045,
  #          "Total" => 0.24937500,
  #          "FillType" => "FILL",
  #          "OrderType" => "BUY"
  #        } | _
  #      ] = trades
  #    end
  #  end

  #  test "should detect an error", %{driver: driver} do
  #    use_cassette "yobit/error" do
  #      {:error, "INVALID_MARKET"} = Cryptozaur.Drivers.YobitRest.get_latest_trades(driver, "BTC", "BAD")
  #    end
  #  end
  #

  #  test "should properly handle a `bad api key` response", %{driver: _driver} do
  #    use_cassette "yobit/auth_bad_key" do
  #      bad_credentials = %{key: "XXX", secret: "YYY"}
  #      {:ok, driver} = Cryptozaur.Drivers.YobitRest.start_link bad_credentials
  #      {:error, "APIKEY_INVALID"} = Cryptozaur.Drivers.YobitRest.get_open_orders(driver)
  #    end
  #  end
  #
  #  test "should properly handle a `bad secret` response", %{driver: _driver} do
  #    use_cassette "yobit/auth_bad_secret" do
  #      bad_credentials = %{key: "319fabede47a40b2819525d8b7c0d1ce", secret: "YYY"}
  #      {:ok, driver} = Cryptozaur.Drivers.YobitRest.start_link bad_credentials
  #      {:error, "INVALID_SIGNATURE"} = Cryptozaur.Drivers.YobitRest.get_open_orders(driver)
  #    end
  #  end

  test "get_info", %{driver: driver} do
    use_cassette "yobit/get_info" do
      {:ok,
       %{
         "funds" => %{
           "eth" => 1.45801326
         },
         "funds_incl_orders" => %{
           "eth" => 1.45801326
         },
         "open_orders" => 0,
         "rights" => %{"deposit" => 1, "info" => 1, "trade" => 1, "withdraw" => 0},
         "server_time" => 1_510_730_817,
         "transaction_count" => 0
       }} = Cryptozaur.Drivers.YobitRest.get_info(driver)
    end
  end

  test "trade should place an order", %{driver: driver} do
    use_cassette "yobit/trade" do
      {:ok,
       %{
         "funds" => %{"etc" => 0, "eth" => 1.44799326},
         "funds_incl_orders" => %{"etc" => 0, "eth" => 1.45801326},
         "order_id" => 102_039_300_267_695,
         "received" => 0,
         "remains" => 1.0,
         "server_time" => 1_510_732_497
       }} = Cryptozaur.Drivers.YobitRest.trade(driver, "buy", "ETC", "ETH", 1.0, 0.01)
    end
  end
end
