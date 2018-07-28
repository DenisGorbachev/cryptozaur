defmodule Cryptozaur.Drivers.LeverexRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :leverex, key: "", secret: "")

    {:ok, driver} = Cryptozaur.Drivers.LeverexRest.start_link(Enum.into(credentials, %{}))

    %{driver: driver}
  end

  test "get_info", %{driver: driver} do
    use_cassette "leverex/get_info", match_requests_on: [:query] do
      {:ok, %{"assets" => %{"BTC" => %{"min_confirmation_count" => 3}, "BTC_D" => %{"min_confirmation_count" => 2}, "BTC_T" => %{"min_confirmation_count" => 3}, "ETH" => %{"min_confirmation_count" => 12}, "ETH_D" => %{"min_confirmation_count" => 2}, "PICK_D" => %{"min_confirmation_count" => 2}}, "markets" => %{"BTC:USDT" => %{"amount_precision" => 8, "base" => "BTC", "delisted_at" => nil, "listed_at" => "2018-06-08T12:00:00", "lot_size" => 0.00000001, "maker_fee" => 0.00100000, "price_precision" => 8, "quote" => "USDT", "taker_fee" => 0.00100000, "tick_size" => 0.00000001}, "ETH_D:BTC_D" => %{"amount_precision" => 8, "base" => "ETH_D", "delisted_at" => nil, "listed_at" => "2018-07-27T12:00:00", "lot_size" => 0.00000001, "maker_fee" => 0.00100000, "price_precision" => 8, "quote" => "BTC_D", "taker_fee" => 0.00100000, "tick_size" => 0.00000001}, "ETH_T:BTC_T" => %{"amount_precision" => 8, "base" => "ETH_T", "delisted_at" => nil, "listed_at" => "2018-06-17T12:00:00", "lot_size" => 0.00000001, "maker_fee" => 0.00100000, "price_precision" => 8, "quote" => "BTC_T", "taker_fee" => 0.00100000, "tick_size" => 0.00000001}}}} = Cryptozaur.Drivers.LeverexRest.get_info(driver)
    end
  end

  test "get_balances", %{driver: driver} do
    use_cassette "leverex/get_balances", match_requests_on: [:query] do
      {:ok,
       [
         %{
           "asset" => "BTC_D",
           "available_amount" => 10.0,
           "total_amount" => 10.0
         },
         %{
           "asset" => "ETH_D",
           "available_amount" => 1000.0,
           "total_amount" => 1000.0
         }
       ]} = Cryptozaur.Drivers.LeverexRest.get_balances(driver)
    end
  end

  test "place_order", %{driver: driver} do
    #    assert {:error, "error"} = Cryptozaur.Drivers.LeverexRest.place_order(driver, "ETH_D:BTC_D", 1.0, 0.00001)
    use_cassette "leverex/place_order" do
      {:ok,
       %{
         "external_id" => nil,
         "called_amount" => 1.0,
         "filled_amount" => 0.0
         # LeverEX returns full order; other properties are not shown
       }} = Cryptozaur.Drivers.LeverexRest.place_order(driver, "ETH_D:BTC_D", 1.0, 0.00001)
    end
  end

  test "cancel_order", %{driver: driver} do
    use_cassette "leverex/cancel_order" do
      {:ok,
       %{
         "external_id" => nil,
         "called_amount" => 1.0,
         "filled_amount" => 0.0
       }} = Cryptozaur.Drivers.LeverexRest.cancel_order(driver, "1")
    end
  end

  #
  #  test "get orders should get the active orders", %{driver: driver} do
  #    use_cassette "leverex/get_open_orders" do
  #      {:ok,
  #        %{
  #          "BUY" => [
  #            %{
  #              "coinType" => "KCS",
  #              "coinTypePair" => "ETH",
  #              "createdAt" => 1516998699000,
  #              "dealAmount" => 0.0,
  #              "direction" => "BUY",
  #              "oid" => "5a6b902a5e39302701af70f8",
  #              "pendingAmount" => 1.0,
  #              "price" => 1.0e-5,
  #              "updatedAt" => 1516998699000,
  #              "userOid" => nil
  #            }
  #          ],
  #          "SELL" => []
  #        }
  #      }
  #      = Cryptozaur.Drivers.LeverexRest.get_open_orders(driver)
  #    end
  #  end
  #
  #  test "get orders should get the closed orders", %{driver: driver} do
  #    use_cassette "leverex/get_closed_orders", match_requests_on: [:query] do
  #      {:ok,
  #        %{
  #          "datas" => [
  #            %{
  #              "amount" => 2.00000000,
  #              "coinType" => "TNC",
  #              "coinTypePair" => "ETH",
  #              "createdAt" => 1517199222000,
  #              "dealDirection" => "SELL",
  #              "dealPrice" => 0.00030300,
  #              "dealValue" => 0.00060600,
  #              "direction" => "BUY",
  #              "fee" => 0.00200000,
  #              "feeRate" => 0.00100000,
  #              "oid" => "5a6e9f7673fb6f11d627adeb",
  #              "orderOid" => "5a6e9f6b87a12d4439beaa2a"
  #            },
  #            %{
  #              "amount" => 1.00000000,
  #              "coinType" => "TNC",
  #              "coinTypePair" => "ETH",
  #              "createdAt" => 1517199123000,
  #              "dealDirection" => "BUY",
  #              "dealPrice" => 0.00031000,
  #              "dealValue" => 0.00031000,
  #              "direction" => "BUY",
  #              "fee" => 0.00100000,
  #              "feeRate" => 0.00100000,
  #              "oid" => "5a6e9f1373fb6f11d627adcf",
  #              "orderOid" => "5a6e9f1273fb6f12b0588de5"
  #            }
  #          ],
  #
  #        }
  #      }
  #      = Cryptozaur.Drivers.LeverexRest.get_closed_orders(driver)
  #    end
  #  end
  #
  #
end
