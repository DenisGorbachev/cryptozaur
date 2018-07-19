defmodule Cryptozaur.Drivers.CryptoCompareRestTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1]

  import Cryptozaur.Utils

  setup_all do
    HTTPoison.start()

    success(driver) = Cryptozaur.Drivers.CryptoCompareRest.start_link(%{key: "key", secret: "secret"})

    %{driver: driver}
  end

  test "CryptoCompare get_coin_shapshot should return a snapshot for specific pair", %{driver: driver} do
    use_cassette "crypto_compare/get_coin_shapshot" do
      success(snapshot) = Cryptozaur.Drivers.CryptoCompareRest.get_coin_shapshot(driver, "ADA", "BTC")

      assert %{
               "AggregatedData" => %{
                 "FLAGS" => "4",
                 "FROMSYMBOL" => "ADA",
                 "HIGH24HOUR" => "0.00006313",
                 "HIGHDAY" => "0.00006185",
                 "LASTMARKET" => "BitTrex",
                 "LASTTRADEID" => "16869585",
                 "LASTUPDATE" => "1515338122",
                 "LASTVOLUME" => "100",
                 "LASTVOLUMETO" => "0.006331",
                 "LOW24HOUR" => "0.00005804",
                 "LOWDAY" => "0.00005869",
                 "MARKET" => "CCCAGG",
                 "OPEN24HOUR" => "0.00006282",
                 "OPENDAY" => "0.00005967",
                 "PRICE" => "0.0000618",
                 "TOSYMBOL" => "BTC",
                 "TYPE" => "5",
                 "VOLUME24HOUR" => "167333671.41953588",
                 "VOLUME24HOURTO" => "10101.937907570002",
                 "VOLUMEDAY" => "106476576.64550087",
                 "VOLUMEDAYTO" => "6422.598041509875"
               },
               "Algorithm" => nil,
               "BlockNumber" => 0,
               "BlockReward" => 0.0,
               "Exchanges" => [
                 %{
                   "FLAGS" => "1",
                   "FROMSYMBOL" => "ADA",
                   "HIGH24HOUR" => "0.00006197",
                   "LASTTRADEID" => "2358042",
                   "LASTUPDATE" => "1515338076",
                   "LASTVOLUME" => "26",
                   "LASTVOLUMETO" => "0.00155662",
                   "LOW24HOUR" => "0.00005821",
                   "MARKET" => "Binance",
                   "OPEN24HOUR" => "0.0000611",
                   "PRICE" => "0.00005987",
                   "TOSYMBOL" => "BTC",
                   "TYPE" => "2",
                   "VOLUME24HOUR" => "71011891",
                   "VOLUME24HOURTO" => "4273.5435651"
                 },
                 %{
                   "FLAGS" => "4",
                   "FROMSYMBOL" => "ADA",
                   "HIGH24HOUR" => "0.00006399",
                   "LASTTRADEID" => "16869585",
                   "LASTUPDATE" => "1515338122",
                   "LASTVOLUME" => "100",
                   "LASTVOLUMETO" => "0.006331",
                   "LOW24HOUR" => "0.00005792",
                   "MARKET" => "BitTrex",
                   "OPEN24HOUR" => "0.0000638",
                   "PRICE" => "0.00006331",
                   "TOSYMBOL" => "BTC",
                   "TYPE" => "2",
                   "VOLUME24HOUR" => "96416252.41953588",
                   "VOLUME24HOURTO" => "5834.174635890002"
                 }
               ],
               "NetHashesPerSecond" => 0.0,
               "ProofType" => nil,
               "TotalCoinsMined" => 25_927_070_538.0
             } == snapshot
    end
  end

  test "CryptoCompare get_torches should return a bucket of torches", %{driver: driver} do
    use_cassette "crypto_compare/get_torches" do
      success(torches) =
        Cryptozaur.Drivers.CryptoCompareRest.get_torches(
          driver,
          "BITFINEX",
          "BTC",
          "USD",
          60,
          now(),
          24 * 60
        )

      # should be 1440, but it looks like CryptoCompare returns an extra torch
      assert length(torches) == 1441
    end
  end

  test "CryptoCompare get_histoday should return a bucket of day-torches", %{driver: driver} do
    use_cassette "crypto_compare/get_histoday" do
      success(torches) =
        Cryptozaur.Drivers.CryptoCompareRest.get_histoday(
          driver,
          "BITFINEX",
          "BTC",
          "USD",
          %{allData: true}
        )

      assert [
               %{
                 "close" => 220.61,
                 "high" => 225,
                 "low" => 215.4,
                 "open" => 224.22,
                 "time" => 1_423_440_000,
                 "volumefrom" => 29625.03,
                 "volumeto" => 6_493_501.42
               },
               %{
                 "close" => 220.96,
                 "high" => 223.88,
                 "low" => 214,
                 "open" => 220.61,
                 "time" => 1_423_526_400,
                 "volumefrom" => 29268.95,
                 "volumeto" => 6_402_350.57
               }
             ] == Enum.take(torches, 2)
    end
  end

  test "CryptoCompare get_histohour should return a bucket of hour-torches", %{driver: driver} do
    use_cassette "crypto_compare/get_histohour" do
      # CryptoCompare always returns limit + 1 entries :)
      limit = 2

      success(torches) = Cryptozaur.Drivers.CryptoCompareRest.get_histohour(driver, "BITTREX", "BTC", "USD", %{limit: limit, aggregate: 2})

      assert [
               %{
                 "close" => 13121,
                 "high" => 13431,
                 "low" => 12893,
                 "open" => 13300.5,
                 "time" => 1_514_865_600,
                 "volumefrom" => 387.52,
                 "volumeto" => 5_072_082.140000001
               },
               %{
                 "close" => 13347.87,
                 "high" => 13357,
                 "low" => 13044,
                 "open" => 13121,
                 "time" => 1_514_872_800,
                 "volumefrom" => 211.84,
                 "volumeto" => 2_805_539.71
               },
               %{
                 "close" => 13400,
                 "high" => 13443,
                 "low" => 13300,
                 "open" => 13347.87,
                 "time" => 1_514_880_000,
                 "volumefrom" => 54.7,
                 "volumeto" => 733_705.5
               }
             ] == torches
    end
  end

  test "CryptoCompare get_coins should return all known currencies", %{driver: driver} do
    use_cassette "crypto_compare/get_coins" do
      success(coins) = Cryptozaur.Drivers.CryptoCompareRest.get_coins(driver)

      assert %{
               "LBTC" => %{
                 "Algorithm" => "Scrypt",
                 "CoinName" => "LiteBitcoin",
                 "FullName" => "LiteBitcoin (LBTC)",
                 "FullyPremined" => "0",
                 "Id" => "247246",
                 "ImageUrl" => "/media/9350763/lbtc.png",
                 "Name" => "LBTC",
                 "PreMinedValue" => "N/A",
                 "ProofType" => "PoW",
                 "SortOrder" => "1533",
                 "Sponsored" => false,
                 "Symbol" => "LBTC",
                 "TotalCoinSupply" => "1000000000",
                 "TotalCoinsFreeFloat" => "N/A",
                 "Url" => "/coins/lbtc/overview"
               },
               "HNC*" => %{
                 "Algorithm" => "X13",
                 "CoinName" => "Huncoin",
                 "FullName" => "Huncoin (HNC*)",
                 "FullyPremined" => "0",
                 "Id" => "373880",
                 "ImageUrl" => "/media/14913529/hnc.png",
                 "Name" => "HNC*",
                 "PreMinedValue" => "N/A",
                 "ProofType" => "PoW",
                 "SortOrder" => "1809",
                 "Sponsored" => false,
                 "Symbol" => "HNC*",
                 "TotalCoinSupply" => "86400000",
                 "TotalCoinsFreeFloat" => "N/A",
                 "Url" => "/coins/hncstar/overview"
               }
             } == Map.take(coins, ["LBTC", "HNC*"])
    end
  end

  test "get_tickers", %{driver: driver} do
    use_cassette "crypto_compare/get_tickers" do
      success(tickers) = Cryptozaur.Drivers.CryptoCompareRest.get_tickers_for_exchange(driver, "BINANCE", ["QSP", "BNB"], ["ETH", "BTC"])

      assert tickers == %{
               "BNB" => %{
                 "BTC" => %{
                   "CHANGEDAY" => 0,
                   "CHANGEPCTDAY" => 0,
                   "FROMSYMBOL" => "BNB",
                   "HIGH24HOUR" => 6.42e-4,
                   "LOW24HOUR" => 5.86e-4,
                   "MARKET" => "Binance",
                   "OPEN24HOUR" => 6.063e-4,
                   "SUPPLY" => 199_013_968,
                   "TOSYMBOL" => "BTC",
                   "TYPE" => "2",
                   "CHANGE24HOUR" => 2.056999999999992e-5,
                   "CHANGEPCT24HOUR" => 3.3927098795975454,
                   "FLAGS" => "1",
                   "LASTTRADEID" => "3384395",
                   "LASTUPDATE" => 1_514_787_141,
                   "LASTVOLUME" => 10,
                   "LASTVOLUMETO" => 0.0062686999999999994,
                   "MKTCAP" => 124_755.88612016,
                   "PRICE" => 6.2687e-4,
                   "TOTALVOLUME24H" => 4_142_801.3805684606,
                   "TOTALVOLUME24HTO" => 2578.6234103469515,
                   "VOLUME24HOUR" => 2_702_035,
                   "VOLUME24HOURTO" => 1675.4501893600006
                 },
                 "ETH" => %{
                   "CHANGEDAY" => 0,
                   "CHANGEPCTDAY" => 0,
                   "FLAGS" => "4",
                   "FROMSYMBOL" => "BNB",
                   "HIGH24HOUR" => 0.012,
                   "LASTVOLUME" => 1,
                   "LOW24HOUR" => 0.01101603,
                   "MARKET" => "Binance",
                   "OPEN24HOUR" => 0.01112993,
                   "SUPPLY" => 199_013_968,
                   "TOSYMBOL" => "ETH",
                   "TYPE" => "2",
                   "CHANGE24HOUR" => 1.768600000000009e-4,
                   "CHANGEPCT24HOUR" => 1.5890486283381917,
                   "LASTTRADEID" => "1381316",
                   "LASTUPDATE" => 1_514_787_138,
                   "LASTVOLUMETO" => 0.01130679,
                   "MKTCAP" => 2_250_209.14324272,
                   "PRICE" => 0.01130679,
                   "TOTALVOLUME24H" => 4_142_801.3805684606,
                   "TOTALVOLUME24HTO" => 46931.050480577665,
                   "VOLUME24HOUR" => 531_977,
                   "VOLUME24HOURTO" => 6104.217482609999
                 }
               },
               "QSP" => %{
                 "BTC" => %{
                   "CHANGEDAY" => 0,
                   "CHANGEPCTDAY" => 0,
                   "FROMSYMBOL" => "QSP",
                   "HIGH24HOUR" => 2.887e-5,
                   "LOW24HOUR" => 2.197e-5,
                   "MARKET" => "Binance",
                   "OPEN24HOUR" => 2.354e-5,
                   "SUPPLY" => 976_442_388.321185,
                   "TOSYMBOL" => "BTC",
                   "TYPE" => "2",
                   "CHANGE24HOUR" => 4.499999999999974e-7,
                   "CHANGEPCT24HOUR" => 1.9116397621070407,
                   "FLAGS" => "1",
                   "LASTTRADEID" => "641786",
                   "LASTUPDATE" => 1_514_787_134,
                   "LASTVOLUME" => 1544,
                   "LASTVOLUMETO" => 0.03704056,
                   "MKTCAP" => 23424.85289582523,
                   "PRICE" => 2.399e-5,
                   "TOTALVOLUME24H" => 105_005_316.3552103,
                   "TOTALVOLUME24HTO" => 2596.700353721495,
                   "VOLUME24HOUR" => 66_090_757,
                   "VOLUME24HOURTO" => 1663.1400747899997
                 },
                 "ETH" => %{
                   "CHANGEDAY" => 0,
                   "CHANGEPCTDAY" => 0,
                   "FROMSYMBOL" => "QSP",
                   "HIGH24HOUR" => 5.279e-4,
                   "LOW24HOUR" => 4.1101e-4,
                   "MARKET" => "Binance",
                   "OPEN24HOUR" => 4.2901e-4,
                   "SUPPLY" => 976_442_388.321185,
                   "TOSYMBOL" => "ETH",
                   "TYPE" => "2",
                   "CHANGE24HOUR" => 5.879999999999991e-6,
                   "CHANGEPCT24HOUR" => 1.3705974219715138,
                   "FLAGS" => "1",
                   "LASTTRADEID" => "268776",
                   "LASTUPDATE" => 1_514_787_129,
                   "LASTVOLUME" => 14,
                   "LASTVOLUMETO" => 0.00608846,
                   "MKTCAP" => 424_645.0302570001,
                   "PRICE" => 4.3489e-4,
                   "TOTALVOLUME24H" => 105_005_316.3552103,
                   "TOTALVOLUME24HTO" => 46232.16189767741,
                   "VOLUME24HOUR" => 18_366_020,
                   "VOLUME24HOURTO" => 8553.59830576
                 }
               }
             }
    end
  end
end
