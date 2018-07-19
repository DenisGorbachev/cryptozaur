defmodule Cryptozaur.Connectors.CoinmarketcapTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.Repo
  alias Cryptozaur.Metronome
  alias Cryptozaur.Connectors.Coinmarketcap
  alias Cryptozaur.Drivers.CoinmarketcapRest, as: Rest

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_briefs" do
    produce_driver(
      [
        {
          {:get_briefs, %{limit: 2}},
          success([
            %{
              "24h_volume_usd" => "12842400000.0",
              "available_supply" => "16767862.0",
              "id" => "bitcoin",
              "last_updated" => "1514473761",
              "market_cap_usd" => "247280691273",
              "max_supply" => "21000000.0",
              "name" => "Bitcoin",
              "percent_change_1h" => "2.28",
              "percent_change_24h" => "-7.06",
              "percent_change_7d" => "-9.02",
              "price_btc" => "1.0",
              "price_usd" => "14747.3",
              "rank" => "1",
              "symbol" => "BTC",
              "total_supply" => "16767862.0"
            },
            %{
              "24h_volume_usd" => "2336750000.0",
              "available_supply" => "96623187.0",
              "id" => "ethereum",
              "last_updated" => "1514473750",
              "market_cap_usd" => "71473427270.0",
              "max_supply" => nil,
              "name" => "Ethereum",
              "percent_change_1h" => "1.91",
              "percent_change_24h" => "-3.52",
              "percent_change_7d" => "-11.45",
              "price_btc" => "0.0510959",
              "price_usd" => "739.713",
              "rank" => "2",
              "symbol" => "ETH",
              "total_supply" => "96623187.0"
            }
          ])
        }
      ],
      Rest,
      :public
    )

    assert success([
             %{:coinmarketcap_id => "bitcoin", :asset => "BTC", :link => "https://coinmarketcap.com/currencies/bitcoin/", :is_complete => true, :market_cap_USD => 247_280_691_273.0, :volume_24h_USD => 1.28424e10},
             %{:coinmarketcap_id => "ethereum", :asset => "ETH", :link => "https://coinmarketcap.com/currencies/ethereum/", :is_complete => true, :market_cap_USD => 71_473_427_270.0, :volume_24h_USD => 2.33675e9}
           ]) == Coinmarketcap.get_briefs(%{limit: 2})
  end
end
