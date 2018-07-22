defmodule Cryptozaur.Model.Balance do
  @moduledoc """
  Balance represents current available amount for a symbol.
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Cryptozaur.Repo
  alias Cryptozaur.Model.Account

  schema "balances" do
    # wallet: exchange, margin, funding, trade, borrow, ... (depends on exchange)
    # equivalent types: exchange, trade
    field(:wallet, :string, default: "exchange")
    field(:currency, :string)
    field(:total_amount, :float)
    field(:available_amount, :float)

    belongs_to(:account, Account)
  end

  @fields [:currency, :amount, :account_id]
  @required @fields
  def fields, do: @fields

  def changeset(balance, params \\ %{}) do
    balance
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def get_amount(pair, account_id) do
    from(
      b in __MODULE__,
      select: b.amount,
      where: b.pair == ^pair,
      where: b.account_id == ^account_id
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

  def all() do
    __MODULE__ |> Repo.all()
  end
end
