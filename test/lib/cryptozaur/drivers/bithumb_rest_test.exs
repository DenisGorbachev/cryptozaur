defmodule Cryptozaur.Drivers.BithumbRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  alias Cryptozaur.Drivers.BithumbRest

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :bithumb, key: "", secret: "")

    {:ok, driver} = Cryptozaur.Drivers.BithumbRest.start_link(Enum.into(credentials, %{}))

    %{driver: driver}
  end

  test "get_ticker", %{driver: driver} do
    use_cassette "bithumb/get_ticker" do
      {:ok, %{"average_price" => "9934041.4787", "buy_price" => "10036000", "closing_price" => "10038000", "date" => "1518494754829", "max_price" => "10220000", "min_price" => "9642000", "opening_price" => "9721000", "sell_price" => "10037000", "units_traded" => "11326.63689343", "volume_1day" => "11326.63689343", "volume_7day" => "109018.77434314"}} = BithumbRest.get_ticker(driver, "BTC", "KRW")
    end
  end

  test "get_tickers", %{driver: driver} do
    use_cassette "bithumb/get_tickers" do
      {:ok,
       %{
         "BCH" => %{
           "average_price" => "1443543.9611",
           "buy_price" => "1422000",
           "closing_price" => "1422000",
           "max_price" => "1476000",
           "min_price" => "1415000",
           "opening_price" => "1435000",
           "sell_price" => "1425000",
           "units_traded" => "10505.12615321",
           "volume_1day" => "10505.12615321",
           "volume_7day" => "228087.742642450000000000"
         },
         "BTC" => %{
           "average_price" => "9934041.4787",
           "buy_price" => "10036000",
           "closing_price" => "10038000",
           "max_price" => "10220000",
           "min_price" => "9642000",
           "opening_price" => "9721000",
           "sell_price" => "10037000",
           "units_traded" => "11326.63689343",
           "volume_1day" => "11326.63689343",
           "volume_7day" => "109018.77434314"
         }
       }} = BithumbRest.get_tickers(driver)
    end
  end
end
