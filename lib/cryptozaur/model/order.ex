defmodule Cryptozaur.Model.Order do
  @moduledoc """
    Orders include full order history: open, partially filled, fully executed
  """

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  import Cryptozaur.Utils

  alias Cryptozaur.Repo
  alias Cryptozaur.Model.Account

  schema "orders" do
    field(:uid, :string)
    field(:pair, :string)
    field(:price, :float)
    # amount of `base` currency affected by the order (= amount - fee?) # has to be stored in DB, because fee may change
    field(:base_diff, :float)
    # amount of `quote` currency affected by the order (= amount * price - fee?) # has to be stored in DB, because fee may change
    field(:quote_diff, :float)
    field(:amount_requested, :float)
    field(:amount_filled, :float)
    # "opened", "closed"
    field(:status, :string)
    field(:timestamp, :naive_datetime)
    timestamps()

    belongs_to(:account, Account)
  end

  @fields [:uid, :pair, :price, :amount_requested, :amount_filled, :status, :timestamp, :account_id, :base_diff, :quote_diff]
  @fields_without_uid @fields -- [:uid]
  @fields_for_maps [:price, :amount_requested, :amount_filled]
  @required @fields
  def fields, do: @fields

  def changeset(order, params \\ %{}) do
    order
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def all() do
    from(
      o in __MODULE__,
      # stabilize tests
      order_by: [asc: o.id]
    )
    |> Repo.all()
  end

  def all_as_maps(fields \\ @fields_for_maps) do
    from(
      o in __MODULE__,
      select: map(o, ^fields),
      # stabilize tests
      order_by: [asc: o.id]
    )
    |> Repo.all()
  end

  def all_as_maps(pair, fields) do
    from(
      o in __MODULE__,
      select: map(o, ^fields),
      where: o.pair == ^pair,
      # stabilize tests
      order_by: [asc: o.timestamp]
    )
    |> Repo.all()
  end

  def all_opened_as_maps(fields \\ @fields_for_maps) do
    from(
      o in __MODULE__,
      select: map(o, ^fields),
      where: o.status == "opened",
      # stabilize tests
      order_by: [asc: o.id]
    )
    |> Repo.all()
  end

  def all_closed_as_maps(fields \\ @fields_for_maps) do
    from(
      o in __MODULE__,
      select: map(o, ^fields),
      where: o.status == "closed",
      # stabilize tests
      order_by: [asc: o.id]
    )
    |> Repo.all()
  end

  def get_fillable_orders_stream(pair, price, amount) do
    if amount > 0.0 do
      from(
        o in __MODULE__,
        where: o.pair == ^pair,
        where: o.price <= ^price,
        where: o.amount_requested < 0.0,
        where: o.amount_filled != o.amount_requested,
        where: o.status == "opened",
        order_by: [asc: o.price, asc: o.timestamp]
      )
    else
      from(
        o in __MODULE__,
        where: o.pair == ^pair,
        where: o.price >= ^price,
        where: o.amount_requested > 0.0,
        where: o.amount_filled != o.amount_requested,
        where: o.status == "opened",
        order_by: [desc: o.price, asc: o.timestamp]
      )
    end
    |> Repo.stream()
  end

  def get_as_map(id) do
    __MODULE__ |> Repo.get(id) |> Map.take(@fields_without_uid)
  end

  def get_base_balance(orders, signs \\ [1.0, -1.0]) do
    orders |> Enum.reduce(0.0, &(&2 + &1.base_diff * if(sign(&1.base_diff) in signs, do: 1.0, else: 0.0)))
  end

  def get_accumulated_base_balance(orders) do
    get_base_balance(orders, [1.0])
  end

  def get_distributed_base_balance(orders) do
    get_base_balance(orders, [-1.0])
  end

  def get_quote_balance(orders) do
    orders
    |> Enum.reduce(0.0, &(&1.quote_diff + &2))
  end

  def get_quote_balance_without_fee(orders) do
    orders
    |> Enum.reduce(0.0, &(-(&1.amount_filled * &1.price) + &2))
  end

  def is_filled(order) do
    order.amount_requested == order.amount_filled
  end
end
