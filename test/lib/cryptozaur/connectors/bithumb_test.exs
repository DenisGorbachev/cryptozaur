defmodule Cryptozaur.Connectors.BithumbTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.Ticker

  @any_secret "secret"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_ticker" do
    produce_driver(
      [
        {
          {:get_ticker, "BTC", "KRW"},
          success(%{
            "average_price" => "9934041.4787",
            "buy_price" => "10036000",
            "closing_price" => "10038000",
            "date" => "1518494754829",
            "max_price" => "10220000",
            "min_price" => "9642000",
            "opening_price" => "9721000",
            "sell_price" => "10037000",
            "units_traded" => "11326.63689343",
            "volume_1day" => "11326.63689343",
            "volume_7day" => "109018.77434314"
          })
        }
      ],
      Cryptozaur.Drivers.BithumbRest,
      :public
    )

    assert success(%Ticker{
             symbol: "BITHUMB:BTC:KRW",
             bid: 10_036_000.0,
             ask: 10_037_000.0,
             volume_24h_base: 11326.63689343
           }) == Connector.get_ticker("BITHUMB", "BTC", "KRW")
  end

  test "get_tickers" do
    produce_driver(
      [
        {
          {:get_tickers},
          success(%{
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
            },
            "date" => "1518494524981"
          })
        }
      ],
      Cryptozaur.Drivers.BithumbRest,
      :public
    )

    assert success([
             %Ticker{
               symbol: "BITHUMB:BCH:KRW",
               bid: 1_422_000.0,
               ask: 1_425_000.0,
               volume_24h_base: 10505.12615321
             },
             %Ticker{
               symbol: "BITHUMB:BTC:KRW",
               bid: 10_036_000.0,
               ask: 10_037_000.0,
               volume_24h_base: 11326.63689343
             }
           ]) == Connector.get_tickers("BITHUMB")
  end
end
