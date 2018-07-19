defmodule Cryptozaur.Model.Depth do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import Cryptozaur.Utils

  alias Cryptozaur.Repo

  schema "depths" do
    field(:symbol, :string)
    field(:buys, :float)
    field(:sells, :float)
    field(:range, :float)
    # interval: [timestamp; timestamp + resolution) # including timestamp, excluding timestamp + resolution
    field(:timestamp, :naive_datetime)
  end

  @fields [:symbol, :buys, :sells, :range, :timestamp]
  @required @fields
  def fields, do: @fields

  def changeset(depth, params \\ %{}) do
    params = if Map.has_key?(params, :timestamp), do: Map.update!(params, :timestamp, &drop_milliseconds/1), else: params

    depth
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def all_as_maps do
    Repo.all(from(s in __MODULE__, select: map(s, @fields)))
  end
end
