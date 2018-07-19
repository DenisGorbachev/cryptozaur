defmodule Cryptozaur.Model.Candle do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import Cryptozaur.Utils

  alias Cryptozaur.Repo

  schema "candles" do
    field(:symbol, :string)
    field(:open, :float)
    field(:high, :float)
    field(:low, :float)
    field(:close, :float)
    field(:buys, :float)
    field(:sells, :float)
    # in seconds
    field(:resolution, :integer)
    # interval: [timestamp; timestamp + resolution) # including timestamp, excluding timestamp + resolution
    field(:timestamp, :naive_datetime)
  end

  @fields [:symbol, :open, :high, :low, :close, :buys, :sells, :resolution, :timestamp]
  @required @fields
  def fields, do: @fields

  def changeset(candle, params \\ %{}) do
    params = if Map.has_key?(params, :timestamp), do: Map.update!(params, :timestamp, &drop_milliseconds/1), else: params

    candle
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def all_latest(symbol, resolution, timestamp, limit) do
    from(
      q in __MODULE__,
      where: q.symbol == ^symbol,
      where: q.resolution == ^resolution,
      where: q.timestamp <= ^timestamp,
      order_by: [desc: :timestamp],
      limit: ^limit
    )
    |> Repo.all()
  end

  def all_as_maps do
    Repo.all(from(s in __MODULE__, select: map(s, @fields)))
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
