defmodule Cryptozaur.Connectors.YobitTest do
  use ExUnit.Case
  #  import OK, only: [success: 1, failure: 1]

  #  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  #  test "Connector should return balances" do
  #    key = produce_driver([
  #      {
  #        {:buy_limit, "DOGE", "BTC", 1, 0.1},
  #        success(%{"uuid" => "5177a54c-7d30-4772-8c63-6d19ea971f82"})
  #      }
  #    ], Cryptozaur.Drivers.YobitRest)
  #
  #    assert success(
  #             "5177a54c-7d30-4772-8c63-6d19ea971f82"
  #           ) == Connector.place_order(@exchange, key, @any_secret, "DOGE", "BTC", 1, 0.1)
  #  end

  #  test "Connector should place a `buy` order and return its uid" do
  #    key = produce_driver([
  #      {
  #        {:buy_limit, "DOGE", "BTC", 1, 0.1},
  #        success(%{"uuid" => "5177a54c-7d30-4772-8c63-6d19ea971f82"})
  #      }
  #    ], Cryptozaur.Drivers.YobitRest)
  #
  #    assert success(
  #      "5177a54c-7d30-4772-8c63-6d19ea971f82"
  #    ) == Connector.place_order(@exchange, key, @any_secret, "DOGE", "BTC", 1, 0.1)
  #  end
end
