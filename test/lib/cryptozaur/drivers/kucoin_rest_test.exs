defmodule Cryptozaur.Drivers.KucoinRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  require OK

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :kucoin, key: "", secret: "")

    {:ok, driver} = Cryptozaur.Drivers.KucoinRest.start_link(Enum.into(credentials, %{}))

    %{driver: driver}
  end

  test "get_tickers should return summary for each pair", %{driver: driver} do
    use_cassette "kucoin/get_tickers" do
      {
        :ok,
        [
          %{
            "buy" => 9.149e-4,
            "change" => 1.534e-5,
            "changeRate" => 0.0171,
            "coinType" => "KCS",
            "coinTypePair" => "BTC",
            "datetime" => 1_516_168_850_000,
            "feeRate" => 0.001,
            "high" => 0.0011,
            "lastDealPrice" => 9.149e-4,
            "low" => 7.2612e-4,
            "sell" => 9.167e-4,
            "sort" => 0,
            "symbol" => "KCS-BTC",
            "trading" => true,
            "vol" => 999_221.6143,
            "volValue" => 892.62923394
          },
          %{
            "buy" => 0.010299,
            "change" => 3.95e-4,
            "changeRate" => 0.0399,
            "coinType" => "KCS",
            "coinTypePair" => "ETH",
            "datetime" => 1_516_168_852_000,
            "feeRate" => 0.001,
            "high" => 0.012,
            "lastDealPrice" => 0.010299,
            "low" => 0.00815,
            "sell" => 0.010303,
            "sort" => 0,
            "symbol" => "KCS-ETH",
            "trading" => true,
            "vol" => 363_115.683,
            "volValue" => 3601.08257551
          },
          %{
            "buy" => 0.001918,
            "change" => 2.89e-4,
            "changeRate" => 0.1605,
            "coinType" => "RPX",
            "coinTypePair" => "NEO",
            "datetime" => 1_516_168_852_000,
            "feeRate" => 0.001,
            "high" => 0.002398,
            "lastDealPrice" => 0.00209,
            "low" => 0.00152,
            "sell" => 0.002042,
            "sort" => 0,
            "symbol" => "RPX-NEO",
            "trading" => true,
            "vol" => 2_154_497.2906,
            "volValue" => 4294.88116717
          },
          %{
            "buy" => 9.59,
            "change" => -0.510001,
            "changeRate" => -0.0505,
            "coinType" => "KCS",
            "coinTypePair" => "USDT",
            "datetime" => 1_516_168_852_000,
            "feeRate" => 0.001,
            "high" => 12.5,
            "lastDealPrice" => 9.59,
            "low" => 5.21,
            "sell" => 9.799999,
            "sort" => 100,
            "symbol" => "KCS-USDT",
            "trading" => true,
            "vol" => 170_927.7396,
            "volValue" => 1_564_099.12850719
          }
          | _
        ]
      } = Cryptozaur.Drivers.KucoinRest.get_tickers(driver)
    end
  end

  test "get_balance should return information about a specific coin", %{driver: driver} do
    use_cassette "kucoin/get_balance" do
      {:ok,
       %{
         "balance" => 0.9953,
         "balanceStr" => "0.9953",
         "coinType" => "ETH",
         "freezeBalance" => 0.0,
         "freezeBalanceStr" => "0.0"
       }} = Cryptozaur.Drivers.KucoinRest.get_balance(driver, "ETH")
    end
  end

  test "get_balances should return information about all the user balances", %{driver: driver} do
    use_cassette "kucoin/get_balances", match_requests_on: [:query] do
      {:ok, result} = Cryptozaur.Drivers.KucoinRest.get_balances(driver)

      assert %{
               "datas" => [
                 %{
                   "balance" => 0.0,
                   "balanceStr" => "0.0",
                   "coinType" => "BCPT",
                   "freezeBalance" => 0.0,
                   "freezeBalanceStr" => "0.0"
                 }
                 | _
               ]
             } = result

      assert length(result["datas"]) == 89
    end
  end

  test "placing a BUY order should create a buy order in the system", %{driver: driver} do
    use_cassette "kucoin/create_order" do
      {:ok, %{"orderOid" => "5a6b902a5e39302701af70f8"}} = Cryptozaur.Drivers.KucoinRest.create_order(driver, "KCS-ETH", 1.0, 0.00001, "BUY")
    end
  end

  test "get orders should get the active orders", %{driver: driver} do
    use_cassette "kucoin/get_open_orders" do
      {:ok,
       %{
         "BUY" => [
           %{
             "coinType" => "KCS",
             "coinTypePair" => "ETH",
             "createdAt" => 1_516_998_699_000,
             "dealAmount" => 0.0,
             "direction" => "BUY",
             "oid" => "5a6b902a5e39302701af70f8",
             "pendingAmount" => 1.0,
             "price" => 1.0e-5,
             "updatedAt" => 1_516_998_699_000,
             "userOid" => nil
           }
         ],
         "SELL" => []
       }} = Cryptozaur.Drivers.KucoinRest.get_open_orders(driver)
    end
  end

  test "get orders should get the closed orders", %{driver: driver} do
    use_cassette "kucoin/get_closed_orders", match_requests_on: [:query] do
      {:ok,
       %{
         "datas" => [
           %{
             "amount" => 2.00000000,
             "coinType" => "TNC",
             "coinTypePair" => "ETH",
             "createdAt" => 1_517_199_222_000,
             "dealDirection" => "SELL",
             "dealPrice" => 0.00030300,
             "dealValue" => 0.00060600,
             "direction" => "BUY",
             "fee" => 0.00200000,
             "feeRate" => 0.00100000,
             "oid" => "5a6e9f7673fb6f11d627adeb",
             "orderOid" => "5a6e9f6b87a12d4439beaa2a"
           },
           %{
             "amount" => 1.00000000,
             "coinType" => "TNC",
             "coinTypePair" => "ETH",
             "createdAt" => 1_517_199_123_000,
             "dealDirection" => "BUY",
             "dealPrice" => 0.00031000,
             "dealValue" => 0.00031000,
             "direction" => "BUY",
             "fee" => 0.00100000,
             "feeRate" => 0.00100000,
             "oid" => "5a6e9f1373fb6f11d627adcf",
             "orderOid" => "5a6e9f1273fb6f12b0588de5"
           }
         ]
       }} = Cryptozaur.Drivers.KucoinRest.get_closed_orders(driver)
    end
  end

  test "placing a cancel BUY order should cancel a buy order in the system", %{driver: driver} do
    use_cassette "kucoin/cancel_order" do
      {:ok, nil} = Cryptozaur.Drivers.KucoinRest.cancel_order(driver, "KCS-ETH", "5a6b902a5e39302701af70f8", "BUY")
    end
  end
end
