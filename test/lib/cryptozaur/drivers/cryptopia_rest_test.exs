defmodule Cryptozaur.Drivers.CryptopiaRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :cryptopia, %{key: "", secret: ""})

    {:ok, driver} = Cryptozaur.Drivers.CryptopiaRest.start_link(credentials)

    %{driver: driver}
  end

  test "get_tickers should return summary for each pair", %{driver: driver} do
    use_cassette "cryptopia/get_tickers" do
      {
        :ok,
        [
          %{
            "Volume" => 83605.6463792,
            "TradePairId" => 1261,
            "SellVolume" => 11_521_285.66923127,
            "SellBaseVolume" => 144_550_398.1728132,
            "Open" => 1.8e-7,
            "Low" => 1.8e-7,
            "LastPrice" => 2.0e-7,
            "Label" => "$$$/BTC",
            "High" => 2.1e-7,
            "Close" => 2.0e-7,
            "Change" => 11.11,
            "BuyVolume" => 9_429_447.65670604,
            "BuyBaseVolume" => 0.47363954,
            "BidPrice" => 2.0e-7,
            "BaseVolume" => 0.01638572,
            "AskPrice" => 2.1e-7
          }
          | _
        ]
      } = Cryptozaur.Drivers.CryptopiaRest.get_tickers(driver)
    end
  end

  #  test "placing a BUY order should create a buy order in the system", %{driver: driver} do
  #    use_cassette "cryptopia/create_order" do
  #      {:ok, %{"orderOid" => "5a6b902a5e39302701af70f8"}}
  #      = Cryptozaur.Drivers.CryptopiaRest.create_order(driver, "KCS-ETH", 1.0, 0.00001, "BUY")
  #    end
  #  end
  #
  #  test "placing a cancel BUY order should cancel a buy order in the system", %{driver: driver} do
  #    use_cassette "cryptopia/cancel_order" do
  #      {:ok, nil}
  #      = Cryptozaur.Drivers.CryptopiaRest.cancel_order(driver, "KCS-ETH", "5a6b902a5e39302701af70f8", "BUY")
  #    end
  #  end
end
