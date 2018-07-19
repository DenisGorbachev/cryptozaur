defmodule Cryptozaur.Model.Account do
  @moduledoc """
  ## Rationale
  * We want to allow developers to connect their own accounts to our system
  * Also, we want to spread our funds among different accounts to avoid withdrawal limits
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  import OK, only: [success: 1, failure: 1]

  alias Cryptozaur.Repo
  alias Cryptozaur.Connector
  alias Cryptozaur.Model.{Balance}

  schema "accounts" do
    field(:exchange, :string)
    field(:key, :string)
    field(:secret, :string)
    timestamps()

    has_many(:balances, Balance)
  end

  @fields [:exchange, :key, :secret]
  @required @fields
  def fields, do: @fields

  def changeset(account, params \\ %{}) do
    account
    |> cast(params, @fields)
    |> validate_required(@required)
    |> validate_change(:exchange, &exchange_is_supported/2)
  end

  def exchange_is_supported(field, value) do
    case Connector.get_exchange_by_slug(value) do
      success(_) -> []
      failure(_) -> [{field, "not supported"}]
    end
  end

  def all_by_exchange(exchange) do
    from(
      o in __MODULE__,
      where: o.exchange == ^exchange,
      order_by: [asc: :id]
    )
    |> Repo.all()
  end

  def first_by_exchange(exchange) do
    from(
      o in __MODULE__,
      where: o.exchange == ^exchange,
      order_by: [asc: :id]
    )
    |> Repo.one!()
  end

  def all_by_keys(keys) do
    from(
      o in __MODULE__,
      where: o.key in ^keys
    )
    |> Repo.all()
  end

  def one_by_key(key) do
    __MODULE__ |> Repo.get_by(key: key)
  end

  def get_latest_id() do
    from(
      o in __MODULE__,
      select: o.id,
      order_by: [desc: o.id],
      limit: 1
    )
    |> Repo.one!()
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

  def all() do
    __MODULE__ |> Repo.all()
  end
end
