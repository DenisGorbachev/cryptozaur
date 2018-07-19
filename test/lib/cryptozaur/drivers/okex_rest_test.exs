defmodule Cryptozaur.Drivers.OkexRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1]
  alias Cryptozaur.Drivers.OkexRest

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :okex, %{key: "", secret: ""})

    {:ok, driver} = Cryptozaur.Drivers.OkexRest.start_link(credentials)

    %{driver: driver}
  end

  test "get_ticker", %{driver: driver} do
    use_cassette "okex/get_ticker" do
      {:ok,
       %{
         "date" => "1517896342",
         "ticker" => %{
           "buy" => "6600.0003",
           "high" => "8316.9499",
           "last" => "6594.0003",
           "low" => "6100.0000",
           "sell" => "6603.1398",
           "vol" => "164520.4297"
         }
       }} = OkexRest.get_ticker(driver, "BTC", "USDT")
    end
  end

  test "get_tickers", %{driver: driver} do
    use_cassette "okex/get_tickers" do
      {:ok,
       [
         %{
           "buy" => "0.01800005",
           "change" => "-0.00037196",
           "changePercentage" => "-2.02%",
           "close" => "0.01802871",
           "createdDate" => 1_518_058_304_372,
           "currencyId" => 12,
           "dayHigh" => "0.01843800",
           "dayLow" => "0.01796600",
           "high" => "0.01878000",
           "last" => "0.01800004",
           "low" => "0.01796600",
           "marketFrom" => 103,
           "name" => "OKEx",
           "open" => "0.01828037",
           "orderIndex" => 0,
           "productId" => 12,
           "sell" => "0.01804973",
           "symbol" => "ltc_btc",
           "volume" => "2208994.07192012"
         },
         %{
           "buy" => "0.10031327",
           "change" => "+0.00063893",
           "changePercentage" => "+0.64%",
           "close" => "0.10046252",
           "createdDate" => 1_518_058_304_372,
           "currencyId" => 13,
           "dayHigh" => "0.10198996",
           "dayLow" => "0.09881000",
           "high" => "0.10205000",
           "last" => "0.10099989",
           "low" => "0.09881000",
           "marketFrom" => 104,
           "name" => "OKEx",
           "open" => "0.10004851",
           "orderIndex" => 0,
           "productId" => 13,
           "sell" => "0.10099989",
           "symbol" => "eth_btc",
           "volume" => "743329.18198642"
         }
         | _
       ]} = OkexRest.get_tickers(driver)
    end
  end

  test "userinfo", %{driver: driver} do
    use_cassette "okex/userinfo" do
      {:ok, result} = Cryptozaur.Drivers.OkexRest.get_userinfo(driver)

      assert %{
               "info" => %{
                 "funds" => %{
                   "borrow" => %{
                     "neo" => "0",
                     "hot" => "0",
                     "ukg" => "0",
                     "lend" => "0",
                     "fair" => "0",
                     "mana" => "0",
                     "cvc" => "0",
                     "rcn" => "0",
                     "snt" => "0",
                     "swftc" => "0",
                     "spf" => "0",
                     "mkr" => "0",
                     "zen" => "0",
                     "ltc" => "0",
                     "insur" => "0",
                     "knc" => "0",
                     "hsr" => "0",
                     "bnt" => "0",
                     "r" => "0",
                     "dat" => "0",
                     "bch" => "0",
                     "dnt" => "0",
                     "dgb" => "0",
                     "viu" => "0",
                     "bcc" => "0",
                     "aac" => "0",
                     "snm" => "0",
                     "mda" => "0",
                     "poe" => "0",
                     "dpy" => "0",
                     "key" => "0",
                     "soc" => "0",
                     "yee" => "0",
                     "elf" => "0",
                     "nano" => "0",
                     "ppt" => "0",
                     "cbt" => "0",
                     "rnt" => "0",
                     "bt2" => "0",
                     "ubtc" => "0",
                     "lrc" => "0",
                     "ast" => "0",
                     "pyn" => "0",
                     "read" => "0",
                     "vee" => "0",
                     "okb" => "0",
                     "btg" => "0"
                   },
                   "free" => %{
                     "neo" => "0",
                     "hot" => "0",
                     "ukg" => "0",
                     "lend" => "0",
                     "fair" => "0",
                     "mana" => "0",
                     "cvc" => "0",
                     "rcn" => "0",
                     "snt" => "0",
                     "swftc" => "0",
                     "spf" => "0",
                     "mkr" => "0",
                     "zen" => "0",
                     "ltc" => "0",
                     "insur" => "0",
                     "knc" => "0",
                     "hsr" => "0",
                     "bnt" => "0",
                     "r" => "0",
                     "dat" => "0",
                     "bch" => "0",
                     "dnt" => "0",
                     "dgb" => "0",
                     "viu" => "0",
                     "bcc" => "0",
                     "aac" => "0",
                     "snm" => "0",
                     "mda" => "0",
                     "poe" => "0",
                     "dpy" => "0",
                     "key" => "0",
                     "soc" => "0",
                     "yee" => "0",
                     "elf" => "0",
                     "nano" => "0",
                     "ppt" => "0",
                     "cbt" => "0",
                     "rnt" => "0",
                     "bt2" => "0",
                     "ubtc" => "0",
                     "lrc" => "0",
                     "ast" => "0",
                     "pyn" => "0",
                     "read" => "0",
                     "vee" => "0",
                     "okb" => "0"
                   },
                   "freezed" => %{
                     "neo" => "0",
                     "hot" => "0",
                     "ukg" => "0",
                     "lend" => "0",
                     "fair" => "0",
                     "mana" => "0",
                     "cvc" => "0",
                     "rcn" => "0",
                     "snt" => "0",
                     "swftc" => "0",
                     "spf" => "0",
                     "mkr" => "0",
                     "zen" => "0",
                     "ltc" => "0",
                     "insur" => "0",
                     "knc" => "0",
                     "hsr" => "0",
                     "bnt" => "0",
                     "r" => "0",
                     "dat" => "0",
                     "bch" => "0",
                     "dnt" => "0",
                     "dgb" => "0",
                     "viu" => "0",
                     "bcc" => "0",
                     "aac" => "0",
                     "snm" => "0",
                     "mda" => "0",
                     "poe" => "0",
                     "dpy" => "0",
                     "key" => "0",
                     "soc" => "0",
                     "yee" => "0",
                     "elf" => "0",
                     "nano" => "0",
                     "ppt" => "0",
                     "cbt" => "0",
                     "rnt" => "0",
                     "bt2" => "0",
                     "ubtc" => "0",
                     "lrc" => "0",
                     "ast" => "0",
                     "pyn" => "0",
                     "read" => "0",
                     "vee" => "0"
                   }
                 }
               },
               "result" => true
             } = result
    end
  end

  test "trade", %{driver: driver} do
    use_cassette "okex/trade_limit_buy" do
      {:ok, %{"order_id" => 30_872_494, "result" => true}} = Cryptozaur.Drivers.OkexRest.trade(driver, "ltc_eth", "buy", 0.1, 0.00001)
    end
  end

  test "cancel_order", %{driver: driver} do
    use_cassette "okex/cancel_order" do
      assert {:ok, %{"order_id" => "30923230", "result" => true}} = Cryptozaur.Drivers.OkexRest.cancel_order(driver, "ltc_eth", 30_923_230)
    end
  end
end
