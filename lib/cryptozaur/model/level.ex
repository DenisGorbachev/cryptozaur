defmodule Cryptozaur.Model.Level do
  @moduledoc """
    The model represents orders from an order book grouped by price.
    It means some orders with the similar price will be represent as a single level with cumulative amount.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import Cryptozaur.Utils

  alias Cryptozaur.Repo

  schema "levels" do
    field(:symbol, :string)
    field(:price, :float)
    field(:amount, :float)
    field(:timestamp, :naive_datetime)
  end

  @fields [:symbol, :price, :amount, :timestamp]
  @required @fields
  def fields, do: @fields

  def changeset(level, params \\ %{}) do
    params = if Map.has_key?(params, :timestamp), do: Map.update!(params, :timestamp, &drop_milliseconds/1), else: params

    level
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def get_latest_snapshot_for(symbol) do
    timestamp = from(l in __MODULE__, order_by: [desc: l.timestamp], limit: 1, select: l.timestamp, where: l.symbol == ^symbol) |> Repo.one()
    from(l in __MODULE__, where: l.timestamp == ^timestamp and l.symbol == ^symbol) |> Repo.all()
  end

  def get_highest_bid_price(symbol, timestamp) do
    # Don't use this function in continuously running code: it puts too much load on the database
    # TODO: add bid + ask fields to Spread model to reduce database load
    from(
      l in __MODULE__,
      select: l.price,
      where: l.amount > 0.0,
      where: l.symbol == ^symbol,
      # <=, so that we can reuse the latest available data even if it's not fully up-to-date
      where: l.timestamp <= ^timestamp,
      order_by: [desc: l.timestamp, desc: l.price],
      limit: 1
    )
    |> Repo.one()

    #    case result do
    #      nil -> raise "Couldn't find highest bid price: no bid levels for #{symbol} at #{timestamp}"
    #      _ -> result
    #    end
  end

  def get_lowest_ask_price(symbol, timestamp) do
    # Don't use this function in continuously running code: it puts too much load on the database
    # TODO: add bid + ask fields to Spread model to reduce database load
    from(
      l in __MODULE__,
      select: l.price,
      where: l.amount < 0.0,
      where: l.symbol == ^symbol,
      # <=, so that we can reuse the latest available data even if it's not fully up-to-date
      where: l.timestamp <= ^timestamp,
      order_by: [desc: l.timestamp, asc: l.price],
      limit: 1
    )
    |> Repo.one()

    #    case result do
    #      nil -> raise "Couldn't find lowest ask price: no ask levels for #{symbol} at #{timestamp}"
    #      _ -> result
    #    end
  end

  def split_into_buys_and_sells(levels) do
    buys = levels |> Enum.filter(&(&1.amount > 0))
    sells = levels |> Enum.filter(&(&1.amount < 0))
    {buys, sells}
  end

  def all_as_maps(fields \\ @fields) do
    from(
      o in __MODULE__,
      select: map(o, ^fields),
      # stabilize tests
      order_by: [asc: o.id]
    )
    |> Repo.all()
  end
end
