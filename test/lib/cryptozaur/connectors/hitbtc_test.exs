defmodule Cryptozaur.Connectors.HitbtcTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Trade}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_trades" do
    produce_driver(
      [
        {
          {:get_trades, "ETH", "BTC", "164215037", "164215055", %{limit: 1000, offset: nil, sort: "DESC", by: "id"}},
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
            }
          ])
        }
      ],
      Cryptozaur.Drivers.HitbtcRest,
      :public
    )

    assert success([
             %Trade{
               uid: "164215055",
               symbol: "HITBTC:ETH:BTC",
               price: 0.091256,
               amount: -0.061,
               timestamp: ~N[2018-01-22 07:38:14.929]
             },
             %Trade{
               uid: "164215038",
               symbol: "HITBTC:ETH:BTC",
               price: 0.091256,
               amount: -0.189,
               timestamp: ~N[2018-01-22 07:38:13.653]
             },
             %Trade{
               uid: "164215037",
               symbol: "HITBTC:ETH:BTC",
               price: 0.091259,
               amount: -0.005,
               timestamp: ~N[2018-01-22 07:38:13.653]
             }
           ]) == Connector.get_trades("HITBTC", "ETH", "BTC", "164215037", "164215055", %{by: "id"})
  end
end
