defmodule Cryptozaur.Model.Trade do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Cryptozaur.Repo

  schema "trades" do
    field(:uid, :string)
    field(:symbol, :string)
    field(:price, :float)
    field(:amount, :float)
    field(:timestamp, :naive_datetime)
  end

  @fields [:uid, :symbol, :price, :amount, :timestamp]
  @required @fields
  def fields, do: @fields

  def changeset(trade, params \\ %{}) do
    trade
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def get_latest(symbol, timestamp) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.timestamp <= ^timestamp,
      order_by: [desc: :timestamp],
      limit: 1
    )
    |> Repo.one!()
  end

  def get_latest_n(limit, symbol, timestamp) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.timestamp <= ^timestamp,
      order_by: [desc: :timestamp],
      limit: ^limit
    )
    |> Repo.all()
  end

  def all_by_symbol_from_to(symbol, from, to) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.timestamp >= ^from,
      where: t.timestamp < ^to,
      order_by: [asc: :timestamp]
    )
    |> Repo.all()
  end

  def average_buys_by_symbol_from_to(symbol, from, to) do
    from(
      t in __MODULE__,
      select: avg(t.amount),
      #      select: fragment("AVG(? * ?)", t.amount, t.price),
      where: t.symbol == ^symbol,
      where: t.amount > 0.0,
      where: t.timestamp >= ^from,
      where: t.timestamp < ^to
    )
    |> Repo.one() || 0.0
  end

  def average_sells_by_symbol_from_to(symbol, from, to) do
    from(
      t in __MODULE__,
      select: avg(t.amount),
      #      select: fragment("AVG(? * ?)", t.amount, t.price),
      where: t.symbol == ^symbol,
      where: t.amount < 0.0,
      where: t.timestamp >= ^from,
      where: t.timestamp < ^to
    )
    |> Repo.one() || 0.0
  end

  def get_latest_buy(symbol, timestamp) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.amount > 0.0,
      where: t.timestamp <= ^timestamp,
      order_by: [desc: t.timestamp],
      limit: 1
    )
    |> Repo.one()
  end

  def get_latest_sell(symbol, timestamp) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.amount < 0.0,
      where: t.timestamp <= ^timestamp,
      order_by: [desc: t.timestamp],
      limit: 1
    )
    |> Repo.one()
  end

  def one_highest_between(symbol, timestamp, now) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.timestamp >= ^timestamp,
      where: t.timestamp <= ^now,
      order_by: [desc: t.price, asc: t.timestamp],
      limit: 1
    )
    |> Repo.one()
  end

  def one_lowest_between(symbol, timestamp, now) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.timestamp >= ^timestamp,
      where: t.timestamp <= ^now,
      order_by: [asc: t.price, asc: t.timestamp],
      limit: 1
    )
    |> Repo.one()
  end

  def get_statistics() do
    from(
      t in __MODULE__,
      select: %{symbol: t.symbol, from: min(t.timestamp), to: max(t.timestamp)},
      group_by: t.symbol
    )
    |> Repo.all()
  end

  def count(symbol) do
    from(
      t in __MODULE__,
      select: count(t.id),
      where: t.symbol == ^symbol
    )
    |> Repo.one()
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
