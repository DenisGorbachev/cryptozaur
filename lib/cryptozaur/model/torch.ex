defmodule Cryptozaur.Model.Torch do
  # Torch is a Candle from https://www.cryptocompare.com/api/#-api-data-histominute-
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import Cryptozaur.Utils

  alias Cryptozaur.Repo

  schema "torches" do
    field(:symbol, :string)
    field(:open, :float)
    field(:high, :float)
    field(:low, :float)
    field(:close, :float)
    field(:volume, :float)
    # in seconds
    field(:resolution, :integer)
    # interval: [timestamp; timestamp + resolution) # including timestamp, excluding timestamp + resolution
    field(:timestamp, :naive_datetime)
  end

  @fields [:symbol, :open, :high, :low, :close, :volume, :resolution, :timestamp]
  @required @fields
  def fields, do: @fields

  def changeset(candle, params \\ %{}) do
    params = if Map.has_key?(params, :timestamp), do: Map.update!(params, :timestamp, &drop_milliseconds/1), else: params

    candle
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

  def one_highest_between(symbol, resolution, from, to) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.resolution == ^resolution,
      where: t.timestamp >= ^from,
      where: t.timestamp <= ^to,
      order_by: [desc: t.high, asc: t.timestamp],
      limit: 1
    )
    |> Repo.one!()
  end

  def one_lowest_between(symbol, resolution, from, to) do
    from(
      t in __MODULE__,
      where: t.symbol == ^symbol,
      where: t.resolution == ^resolution,
      where: t.timestamp >= ^from,
      where: t.timestamp <= ^to,
      order_by: [asc: t.low, asc: t.timestamp],
      limit: 1
    )
    |> Repo.one!()
  end

  def count_by_symbol(symbol) do
    from(t in __MODULE__, where: t.symbol == ^symbol) |> Repo.aggregate(:count, :id)
  end

  def all_as_maps(fields \\ @fields) do
    from(
      o in __MODULE__,
      select: map(o, ^fields),
      # stabilize tests
      order_by: [asc: o.timestamp]
    )
    |> Repo.all()
  end

  def all_as_maps_with_nonzero_volume do
    from(
      s in __MODULE__,
      select: map(s, @fields),
      where: s.buys != 0.0,
      or_where: s.sells != 0.0,
      # stabilize tests
      order_by: [asc: s.timestamp]
    )
    |> Repo.all()
  end
end
