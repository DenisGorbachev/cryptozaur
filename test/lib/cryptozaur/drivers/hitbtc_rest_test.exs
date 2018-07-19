defmodule Cryptozaur.Drivers.HitbtcRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1, failure: 1]

  setup_all do
    success(_) = HTTPoison.start()
    success(driver) = Cryptozaur.Drivers.HitbtcRest.start_link(Application.get_env(:cryptozaur, :hitbtc, %{key: "", secret: ""}))
    %{driver: driver}
  end

  test "get_trades", %{driver: driver} do
    use_cassette "hitbtc/get_trades" do
      result =
        success([
          %{
            "id" => 164_215_055,
            "price" => "0.091256",
            "quantity" => "0.061",
            "side" => "sell",
            "timestamp" => "2018-01-22T07:38:14.929Z"
          },
          %{
            "id" => 164_215_038,
            "price" => "0.091256",
            "quantity" => "0.189",
            "side" => "sell",
            "timestamp" => "2018-01-22T07:38:13.653Z"
          },
          %{
            "id" => 164_215_037,
            "price" => "0.091259",
            "quantity" => "0.005",
            "side" => "sell",
            "timestamp" => "2018-01-22T07:38:13.653Z"
          },
          %{
            "id" => 164_215_036,
            "price" => "0.091259",
            "quantity" => "0.007",
            "side" => "sell",
            "timestamp" => "2018-01-22T07:38:13.653Z"
          }
        ])

      assert Cryptozaur.Drivers.HitbtcRest.get_trades(driver, "ETH", "BTC", 164_215_036, 164_215_055, %{by: "id"}) == result
      assert Cryptozaur.Drivers.HitbtcRest.get_trades(driver, "ETH", "BTC", ~N[2018-01-22 07:38:13.653], ~N[2018-01-22 07:38:14.929], %{by: "timestamp"}) == result
    end
  end

  test "get_orderbook", %{driver: driver} do
    use_cassette "hitbtc/orderbook" do
      #      {:ok, result} = Cryptozaur.Drivers.HitbtcRest.get_orderbook(driver, "DOGE", "BTC")
      #      Apex.ap(result["ask"] |> Enum.at(0), numbers: false)
      #      Apex.ap(result["bid"] |> Enum.at(0), numbers: false)
      {:ok,
       %{
         "ask" => [
           %{"price" => "0.000000588", "size" => "120000"}
           | _
         ],
         "bid" => [
           %{"price" => "0.000000587", "size" => "6547000"}
           | _
         ]
       }} = Cryptozaur.Drivers.HitbtcRest.get_orderbook(driver, "DOGE", "BTC")
    end
  end
end
