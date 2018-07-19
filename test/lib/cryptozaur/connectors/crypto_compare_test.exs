defmodule Cryptozaur.Connectors.CryptoCompareTest do
  use ExUnit.Case
  import OK, only: [success: 1, ~>>: 2]

  import Cryptozaur.Case
  alias Cryptozaur.Repo
  alias Cryptozaur.Metronome
  alias Cryptozaur.Model.{Torch, Ticker}
  alias Cryptozaur.Connectors.CryptoCompare

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "Connector should return Torch structs" do
    produce_driver(
      [
        {
          {:get_torches, "Bitfinex", "BTC", "USD", 60, 1_504_705_252, 1440},
          success([
            %{
              "close" => 5527.9,
              "high" => 5528,
              "low" => 5527.9,
              "open" => 5527.9,
              "time" => 1_508_083_140,
              "volumefrom" => 5.37,
              "volumeto" => 29700.69
            },
            %{
              "close" => 5527.9,
              "high" => 5528,
              "low" => 5527.9,
              "open" => 5527.9,
              "time" => 1_508_083_200,
              "volumefrom" => 11.11,
              "volumeto" => 61399.93
            }
          ])
        }
      ],
      Cryptozaur.Drivers.CryptoCompareRest,
      :public
    )

    assert success([
             %Torch{
               symbol: "BITFINEX:BTC:USD",
               close: 5527.9,
               high: 5528.0,
               low: 5527.9,
               open: 5527.9,
               resolution: 60,
               timestamp: ~N[2017-10-15 15:59:00],
               volume: 5.37000000
             },
             %Torch{
               symbol: "BITFINEX:BTC:USD",
               close: 5527.9,
               high: 5528.0,
               low: 5527.9,
               open: 5527.9,
               resolution: 60,
               timestamp: ~N[2017-10-15 16:00:00],
               volume: 11.11000000
             }
           ]) == CryptoCompare.get_torches("BITFINEX", "BTC", "USD", 60, ~N[2017-09-06 13:40:52], 1440)
  end

  test "Connector should return torch structs for `day` resolution" do
    produce_driver(
      [
        {
          {:get_torches, "Bitfinex", "BTC", "USD", 24 * 60 * 60, 1_423_526_400, 2},
          success([
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
          ])
        }
      ],
      Cryptozaur.Drivers.CryptoCompareRest,
      :public
    )

    assert success([
             %Torch{
               symbol: "BITFINEX:BTC:USD",
               close: 220.61,
               high: 225.0,
               low: 215.4,
               open: 224.22,
               resolution: 86400,
               timestamp: ~N[2015-02-09 00:00:00],
               volume: 29625.03000000
             },
             %Torch{
               symbol: "BITFINEX:BTC:USD",
               close: 220.96,
               high: 223.88,
               low: 214.0,
               open: 220.61,
               resolution: 86400,
               timestamp: ~N[2015-02-10 00:00:00],
               volume: 29268.95000000
             }
           ]) == CryptoCompare.get_torches("BITFINEX", "BTC", "USD", 24 * 60 * 60, ~N[2015-02-10 00:00:00], 2)
  end

  test "Connector should return torch structs for `hour` resolution" do
    produce_driver(
      [
        {
          {:get_torches, "BitTrex", "BTC", "USD", 2 * 60 * 60, 1_514_880_000, 3},
          success([
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
          ])
        }
      ],
      Cryptozaur.Drivers.CryptoCompareRest,
      :public
    )

    assert success([
             %Torch{
               symbol: "BITTREX:BTC:USD",
               close: 13121.0,
               high: 13431.0,
               low: 12893.0,
               open: 13300.5,
               resolution: 7200,
               timestamp: ~N[2018-01-02 04:00:00],
               volume: 387.52000000
             },
             %Torch{
               symbol: "BITTREX:BTC:USD",
               close: 13347.87,
               high: 13357.0,
               low: 13044.0,
               open: 13121.0,
               resolution: 7200,
               timestamp: ~N[2018-01-02 06:00:00],
               volume: 211.84000000
             },
             %Torch{
               symbol: "BITTREX:BTC:USD",
               close: 13400.0,
               high: 13443.0,
               low: 13300.0,
               open: 13347.87,
               resolution: 7200,
               timestamp: ~N[2018-01-02 08:00:00],
               volume: 54.7000000
             }
           ]) == CryptoCompare.get_torches("BITTREX", "BTC", "USD", 2 * 60 * 60, ~N[2018-01-02 08:00:00], 3)
  end

  test "Connector should return list of known currencies" do
    produce_driver(
      [
        {
          {:get_coins},
          success(%{
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
          })
        }
      ],
      Cryptozaur.Drivers.CryptoCompareRest,
      :public
    )

    assert ["HNC*", "LBTC"] == CryptoCompare.get_currencies() ~>> Enum.sort()
  end

  test "get_tickers_for_exchange" do
    produce_driver(
      {
        {:get_tickers_for_exchange, "Binance", ["BNB"], ["BTC"], %{}},
        success(%{
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
            }
          }
        })
      }
      |> List.duplicate(2),
      Cryptozaur.Drivers.CryptoCompareRest,
      :public
    )

    ticker = %Ticker{
      symbol: "BINANCE:BNB:BTC",
      bid: 0.00062687,
      ask: 0.00062687,
      volume_24h_base: 2_702_035.0,
      volume_24h_quote: 1675.4501893600006
    }

    assert success(ticker) == CryptoCompare.get_ticker_for_exchange("BINANCE", "BNB", "BTC")
    assert success([ticker]) == CryptoCompare.get_tickers_for_exchange("BINANCE", ["BNB"], ["BTC"])
  end
end
