defmodule Cryptozaur.Drivers.BinanceRestTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  import OK, only: [success: 1, failure: 1]
  alias Cryptozaur.Drivers.BinanceRest, as: Rest

  setup_all do
    HTTPoison.start()
    credentials = Application.get_env(:cryptozaur, :binance, key: "", secret: "")
    success(driver) = Rest.start_link(Enum.into(credentials, %{}))

    %{
      driver: driver
    }
  end

  test "error should be recognised successfully", %{driver: driver} do
    use_cassette "binance/error_handling" do
      assert failure("Invalid symbol.") == Rest.get_aggregated_trades(driver, "ASD", "BTC")
    end
  end

  test "get_aggregated_trades", %{driver: driver} do
    use_cassette "binance/get_aggregated_trades_success" do
      success(trades) = Rest.get_aggregated_trades(driver, "LTC", "BTC", %{limit: 2})

      expected = [
        %{
          "M" => true,
          "T" => 1_516_538_545_703,
          "a" => 4_969_786,
          "f" => 5_576_148,
          "l" => 5_576_148,
          "m" => true,
          "p" => "0.01624400",
          "q" => "0.53000000"
        },
        %{
          "M" => true,
          "T" => 1_516_538_546_392,
          "a" => 4_969_787,
          "f" => 5_576_149,
          "l" => 5_576_149,
          "m" => false,
          "p" => "0.01627100",
          "q" => "0.22000000"
        }
      ]

      assert expected == trades
    end
  end

  test "get_aggregated_trades (with NaiveDateTime timestamps)", %{driver: driver} do
    use_cassette "binance/get_aggregated_trades_timestamps_success" do
      success(trades) = Rest.get_aggregated_trades(driver, "LTC", "BTC", %{limit: 2, startTime: ~N[2018-01-01 12:00:00], endTime: ~N[2018-01-01 12:00:30]})

      expected = [
        %{
          "M" => true,
          "T" => 1_514_808_028_984,
          "a" => 3_171_735,
          "f" => 3_485_714,
          "l" => 3_485_714,
          "m" => true,
          "p" => "0.01685500",
          "q" => "0.38000000"
        },
        %{
          "M" => true,
          "T" => 1_514_808_029_570,
          "a" => 3_171_736,
          "f" => 3_485_715,
          "l" => 3_485_715,
          "m" => true,
          "p" => "0.01685500",
          "q" => "0.46000000"
        }
      ]

      assert expected == trades
    end
  end

  test "get_levels", %{driver: driver} do
    use_cassette "binance/get_levels" do
      success(%{"bids" => bids, "asks" => asks}) = Rest.get_levels(driver, "LTC", "BTC", 50)

      assert Enum.take(bids, 2) == [["0.01571700", "4.83000000", []], ["0.01571600", "0.07000000", []]]
      assert Enum.take(asks, 2) == [["0.01571900", "0.07000000", []], ["0.01573100", "16.75000000", []]]
    end
  end

  test "get_all_orders", %{driver: driver} do
    use_cassette "binance/get_all_orders" do
      success(result) = Rest.get_all_orders(driver, "VIB", "ETH")

      assert result == [
               %{
                 "clientOrderId" => "aRaw4TYQaliMa3sdRHR7fH",
                 "executedQty" => "0.00000000",
                 "icebergQty" => "0.00000000",
                 "isWorking" => true,
                 "orderId" => 4_617_719,
                 "origQty" => "1000.00000000",
                 "price" => "0.00050330",
                 "side" => "BUY",
                 "status" => "CANCELED",
                 "stopPrice" => "0.00000000",
                 "symbol" => "VIBETH",
                 "time" => 1_517_154_388_695,
                 "timeInForce" => "GTC",
                 "type" => "LIMIT"
               },
               %{
                 "clientOrderId" => "0whSa0EkQxetlHwtarCY1x",
                 "executedQty" => "0.00000000",
                 "icebergQty" => "0.00000000",
                 "isWorking" => true,
                 "orderId" => 4_618_131,
                 "origQty" => "1000.00000000",
                 "price" => "0.00050330",
                 "side" => "BUY",
                 "status" => "NEW",
                 "stopPrice" => "0.00000000",
                 "symbol" => "VIBETH",
                 "time" => 1_517_154_546_719,
                 "timeInForce" => "GTC",
                 "type" => "LIMIT"
               }
             ]
    end
  end

  test "get_my_trades", %{driver: driver} do
    use_cassette "binance/get_my_trades" do
      success(result) = Rest.get_my_trades(driver, "TRX", "ETH")

      assert result == [
               %{
                 "commission" => "0.00100000",
                 "commissionAsset" => "TRX",
                 "id" => 7_190_890,
                 "isBestMatch" => true,
                 "isBuyer" => true,
                 "isMaker" => false,
                 "orderId" => 15_163_752,
                 "price" => "0.00004310",
                 "qty" => "1.00000000",
                 "time" => 1_517_579_526_858
               }
             ]
    end
  end

  test "get_torches", %{driver: driver} do
    use_cassette "binance/get_torches" do
      success(result) = Rest.get_torches(driver, "TRX", "ETH", ~N[2018-03-01 12:00:00], ~N[2018-03-01 15:00:00], 3600)

      assert result == [
               [
                 1_519_905_600_000,
                 "0.00005152",
                 "0.00005280",
                 "0.00005122",
                 "0.00005222",
                 "35059726.00000000",
                 1_519_909_199_999,
                 "1813.80650519",
                 2122,
                 "29283383.00000000",
                 "1514.57338614",
                 "0"
               ],
               [
                 1_519_909_200_000,
                 "0.00005238",
                 "0.00005364",
                 "0.00005182",
                 "0.00005289",
                 "47867600.00000000",
                 1_519_912_799_999,
                 "2528.09408946",
                 3797,
                 "40504050.00000000",
                 "2139.17941565",
                 "0"
               ],
               [
                 1_519_912_800_000,
                 "0.00005289",
                 "0.00005359",
                 "0.00005288",
                 "0.00005310",
                 "44123292.00000000",
                 1_519_916_399_999,
                 "2349.51250852",
                 3207,
                 "36523647.00000000",
                 "1945.10557672",
                 "0"
               ],
               [
                 1_519_916_400_000,
                 "0.00005312",
                 "0.00005321",
                 "0.00005211",
                 "0.00005257",
                 "38174019.00000000",
                 1_519_919_999_999,
                 "2008.21752155",
                 2600,
                 "31282237.00000000",
                 "1645.61719666",
                 "0"
               ]
             ]
    end
  end
end
