defmodule Cryptozaur.Connectors.LeverexTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Order, Ticker, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_balances" do
    key =
      produce_driver(
        [
          {
            {:get_balances},
            success([
              %{
                "asset" => "BTCT",
                "available_amount" => 5.0,
                "total_amount" => 10.0
              },
              %{
                "asset" => "ETHT",
                "available_amount" => 500.0,
                "total_amount" => 1000.0
              }
            ])
          }
        ],
        Cryptozaur.Drivers.LeverexRest
      )

    assert success([
             %Balance{amount: 10.0, currency: "BTCT"},
             %Balance{amount: 1000.0, currency: "ETHT"}
           ]) = Connector.get_balances("LEVEREX", key, "secret")
  end
end
