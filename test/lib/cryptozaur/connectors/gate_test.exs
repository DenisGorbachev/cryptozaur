defmodule Cryptozaur.Connectors.GateTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.Ticker

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "Connector should return tickers" do
    produce_driver(
      [
        {
          {:get_tickers},
          success(%{
            "btc_usdt" => %{
              "result" => "true",
              "last" => 15284,
              "lowestAsk" => 15283.9,
              "highestBid" => 15183.8,
              "percentChange" => -3.0535190778979,
              "baseVolume" => 15_764_633.61,
              "quoteVolume" => 1043.2563,
              "high24hr" => 16100.11,
              "low24hr" => 13400
            },
            "bch_usdt" => %{
              "result" => "true",
              # sometimes API returns strings... :|
              "last" => "2367.12",
              "lowestAsk" => "2417.7",
              "highestBid" => "2369.51",
              "percentChange" => "-4.559309739525",
              "baseVolume" => "1255683.07",
              "quoteVolume" => "527.1902",
              "high24hr" => "2543.82",
              "low24hr" => "2090.08"
            }
          })
        }
      ],
      Cryptozaur.Drivers.GateRest,
      :public
    )

    assert success([
             %Ticker{
               symbol: "GATE:BCH:USDT",
               bid: 2369.51,
               ask: 2417.7,
               volume_24h_base: 1_255_683.07,
               volume_24h_quote: 527.1902
             },
             %Ticker{
               symbol: "GATE:BTC:USDT",
               bid: 15183.8,
               ask: 15283.9,
               volume_24h_base: 15_764_633.61,
               volume_24h_quote: 1043.2563
             }
           ]) == Connector.get_tickers("GATE")
  end
end
