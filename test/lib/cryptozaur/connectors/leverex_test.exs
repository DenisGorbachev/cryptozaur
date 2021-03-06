defmodule Cryptozaur.Connectors.LeverexTest do
  use ExUnit.Case
  import OK, only: [success: 1]

  import Cryptozaur.Case
  alias Cryptozaur.{Repo, Metronome, Connector}
  alias Cryptozaur.Model.{Balance, Order}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, metronome} = start_supervised(Metronome)
    {:ok, _} = start_supervised(Cryptozaur.DriverSupervisor)
    %{metronome: metronome}
  end

  test "get_info" do
    produce_driver(
      [
        {
          {:get_info, []},
          success(%{"markets" => %{}, "assets" => %{}})
        }
      ],
      Cryptozaur.Drivers.LeverexRest,
      :public
    )

    assert success(%{"markets" => %{}, "assets" => %{}}) == Connector.get_info("LEVEREX")
  end

  test "get_balances" do
    key =
      produce_driver(
        [
          {
            {:get_balances, []},
            success([
              %{
                "asset" => "BTCT",
                "available_amount" => 5.0,
                "placed_amount" => 5.0,
                "withdrawn_amount" => 0.0
              },
              %{
                "asset" => "ETHT",
                "available_amount" => 500.0,
                "placed_amount" => 200.0,
                "withdrawn_amount" => 300.0
              }
            ])
          }
        ],
        Cryptozaur.Drivers.LeverexRest
      )

    assert success([
             %Balance{available_amount: 5.0, total_amount: 10.0, currency: "BTCT"},
             %Balance{available_amount: 500.0, total_amount: 1000.0, currency: "ETHT"}
           ]) = Connector.get_balances("LEVEREX", key, "secret")
  end

  test "get_orders" do
    key =
      produce_driver(
        [
          {
            {:get_orders, nil, []},
            success([
              %{
                "cancelled_at" => nil,
                "external_id" => nil,
                "fee" => 0.00000000,
                "filled_amount" => 0.00000000,
                "filled_total" => 0.00000000,
                "id" => 1201,
                "inserted_at" => "2018-07-30T09:03:11.490970",
                "is_active" => true,
                "limit_price" => 0.00000001,
                "requested_amount" => 0.00000001,
                "symbol" => "ETH_D:BTC_D",
                "trigger_price" => nil,
                "triggered_at" => "2018-07-30T09:03:11.490970",
                "updated_at" => "2018-08-06T07:02:52.491043"
              },
              %{
                "cancelled_at" => nil,
                "external_id" => nil,
                "fee" => -0.00014,
                "filled_amount" => 2.00000000,
                "filled_total" => -0.14000000,
                "id" => 1200,
                "inserted_at" => "2018-07-30T09:03:11.490970",
                "is_active" => true,
                "limit_price" => 0.07000000,
                "requested_amount" => 2.00000000,
                "symbol" => "ETH_D:BTC_D",
                "trigger_price" => nil,
                "triggered_at" => "2018-07-30T09:03:11.490970",
                "updated_at" => "2018-07-30T09:03:11.490970"
              },
              %{
                "cancelled_at" => "2018-07-30T11:34:24.343425",
                "external_id" => nil,
                "fee" => 0.00000000,
                "filled_amount" => 0.00000000,
                "filled_total" => 0.00000000,
                "id" => 1199,
                "inserted_at" => "2018-07-30T09:03:11.490970",
                "is_active" => true,
                "limit_price" => 0.00000001,
                "requested_amount" => 0.00000001,
                "symbol" => "ETH_D:BTC_D",
                "trigger_price" => nil,
                "triggered_at" => "2018-07-30T09:03:11.490970",
                "updated_at" => "2018-07-30T09:03:11.490970"
              }
            ])
          }
        ],
        Cryptozaur.Drivers.LeverexRest
      )

    assert success([
             %Order{
               amount_filled: 0.00000000,
               amount_requested: 0.00000001,
               base_diff: 0.00000000,
               pair: "ETH_D:BTC_D",
               price: 0.00000001,
               quote_diff: 0.00000000,
               status: "opened",
               timestamp: ~N[2018-07-30 09:03:11.490970],
               uid: 1201
             },
             %Order{
               amount_filled: 2.00000000,
               amount_requested: 2.00000000,
               base_diff: 2.00000000,
               pair: "ETH_D:BTC_D",
               price: 0.07000000,
               quote_diff: -0.14000000 + -0.00014,
               status: "closed",
               timestamp: ~N[2018-07-30 09:03:11.490970],
               uid: 1200
             },
             %Order{
               amount_filled: 0.00000000,
               amount_requested: 0.00000001,
               base_diff: 0.00000000,
               pair: "ETH_D:BTC_D",
               price: 0.00000001,
               quote_diff: 0.00000000,
               status: "closed",
               timestamp: ~N[2018-07-30 09:03:11.490970],
               uid: 1199
             }
           ]) == Connector.get_orders("LEVEREX", key, "secret")
  end

  test "place_order" do
    key =
      produce_driver(
        [
          {
            {:place_order, "ETH_D:BTC_D", 1, 0.0000100, []},
            success(%{
              "requested_amount" => 1.00000000,
              "external_id" => nil,
              "fee" => 0.00000000,
              "filled_amount" => 0.00000000,
              "id" => 4,
              "inserted_at" => "2018-07-27T13:11:53.200832",
              "is_active" => true,
              "is_cancelled" => false,
              "limit_price" => 0.00001000,
              "symbol" => "ETH_D:BTC_D",
              "trigger_price" => nil,
              "triggered_at" => "2018-07-27T13:11:53.200536",
              "updated_at" => "2018-07-27T13:11:53.200840"
            })
          }
        ],
        Cryptozaur.Drivers.LeverexRest
      )

    assert success("4") == Connector.place_order("LEVEREX", key, "secret", "ETH_D", "BTC_D", 1, 0.00001)
  end

  test "cancel_order" do
    key =
      produce_driver(
        [
          {
            {:cancel_order, "4", []},
            success(%{
              "id" => 4
              # LeverEX returns full order; other properties are not shown
            })
          }
        ],
        Cryptozaur.Drivers.LeverexRest
      )

    assert success("4") == Connector.cancel_order("LEVEREX", key, "secret", "ETH_D", "BTC_D", "4")
  end
end
