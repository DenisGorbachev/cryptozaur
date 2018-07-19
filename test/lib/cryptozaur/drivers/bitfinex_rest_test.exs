defmodule Cryptozaur.Drivers.BitfinexRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :bitfinex, %{key: "", secret: ""})

    {:ok, driver} = Cryptozaur.Drivers.BitfinexRest.start_link(credentials)

    %{driver: driver}
  end

  test "Bitfinex get_candles should return a bucket of candles", %{driver: driver} do
    use_cassette "bitfinex/get_candles" do
      {:ok, candles} = Cryptozaur.Drivers.BitfinexRest.get_candles(driver, "BTC", "USD", 1, %{limit: 2})

      assert [
               [1_518_061_620_000, 8080, 8077.30000000, 8080, 8077.30000000, 9.10864322],
               [1_518_061_560_000, 8081.10000000, 8081.63235209, 8117, 8080, 75.04939746]
             ] == candles
    end
  end

  test "get symbols", %{driver: driver} do
    use_cassette "bitfinex/get_symbols" do
      {:ok,
       [
         "btcusd",
         "ltcusd",
         "ltcbtc",
         "ethusd",
         "ethbtc",
         "etcbtc"
         | _
       ]} = Cryptozaur.Drivers.BitfinexRest.get_symbols(driver)
    end
  end

  test "get ticker", %{driver: driver} do
    use_cassette "bitfinex/get_ticker" do
      {:ok,
       [
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
       ]} = Cryptozaur.Drivers.BitfinexRest.get_ticker(driver, "BTC", "USD")
    end
  end

  test "get tickers", %{driver: driver} do
    use_cassette "bitfinex/get_tickers", match_requests_on: [:query] do
      {:ok,
       [
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
         | _
       ]} = Cryptozaur.Drivers.BitfinexRest.get_tickers(driver)
    end
  end

  test "Bitfinex get_trades should return a bucket of trades", %{driver: driver} do
    use_cassette "bitfinex/get_trades" do
      {:ok, trades} = Cryptozaur.Drivers.BitfinexRest.get_trades(driver, "BTC", "USD")
      [[190_892_528, 1_518_061_648_514, 0.01411049, 8077.30000000] | _] = trades
    end
  end

  test "Bitfinex get_trades with parameters should return a bucket of trades", %{driver: driver} do
    use_cassette "bitfinex/get_trades_with_parameters" do
      # bypass a bug with IDE syntax highlighting (https://github.com/KronicDeth/intellij-elixir/issues/821)
      parameters =
        %{start: 1_508_741_249_653, limit: 1000}
        |> Map.put_new(:end, 1_508_751_249_653)

      {:ok, trades} = Cryptozaur.Drivers.BitfinexRest.get_trades(driver, "BTC", "USD", parameters)
      assert length(trades) == 1000
      [[80_493_398, 1_508_751_249_000, 0.12481359, 5808.10000000] | _] = trades
    end
  end

  test "Bitfinex get_order_book should return a bucket of orders", %{driver: driver} do
    use_cassette "bitfinex/get_order_book" do
      {:ok, orders} = Cryptozaur.Drivers.BitfinexRest.get_order_book(driver, "BTC", "USD")
      [[8077.20000000, 1, 0.04380000] | _] = orders
    end
  end

  #  test "Bitfinex get_balances should return user balances", %{driver: driver} do
  #    use_cassette "bitfinex/get_balances" do
  #      {:ok, balances} = Cryptozaur.Drivers.BitfinexRest.get_balances(driver)
  #    end
  #  end

  test "Bitfinex should detect an error", %{driver: driver} do
    use_cassette "bitfinex/error" do
      incorrect_end_timestamp = 1_098_751_849_653

      parameters =
        %{start: 1_498_741_249_653}
        |> Map.put_new(:end, incorrect_end_timestamp)

      {:error, "10020: time_interval: invalid"} = Cryptozaur.Drivers.BitfinexRest.get_trades(driver, "BTC", "USD", parameters)
    end
  end
end
