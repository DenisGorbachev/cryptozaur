defmodule Cryptozaur.Drivers.GateRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :gate, %{key: "", secret: ""})

    {:ok, driver} = Cryptozaur.Drivers.GateRest.start_link(credentials)

    %{driver: driver}
  end

  test "get_tickers should return summary for each pair", %{driver: driver} do
    use_cassette "gate/get_tickers" do
      {:ok,
       %{
         "btc_usdt" => %{
           "result" => "true",
           "last" => 15197.85,
           "lowestAsk" => 15274.22,
           "highestBid" => 15250.66,
           "percentChange" => -3.3830260648442,
           "baseVolume" => 15_762_366.9,
           "quoteVolume" => 1043.2285,
           "high24hr" => 16100.11,
           "low24hr" => 13400
         }
       }} = Cryptozaur.Drivers.GateRest.get_tickers(driver)
    end
  end

  test "get_balance should return current balance", %{driver: driver} do
    use_cassette "gate/get_balance" do
      {:ok, %{"available" => [], "result" => "true"}} = Cryptozaur.Drivers.GateRest.get_balance(driver)
    end
  end
end
