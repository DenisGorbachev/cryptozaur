defmodule Cryptozaur.Model.Ticker do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Cryptozaur.Repo

  schema "tickers" do
    field(:symbol, :string)
    field(:bid, :float)
    field(:ask, :float)
    # some exchanges provide either volume_24h_base or volume_24h_quote
    field(:volume_24h_base, :float, default: nil)
    # some exchanges provide either volume_24h_base or volume_24h_quote
    field(:volume_24h_quote, :float, default: nil)
    timestamps()
  end

  @fields [:symbol, :bid, :ask, :volume_24h_base, :volume_24h_quote]
  @required @fields -- [:volume_24h_base, :volume_24h_quote]
  def fields, do: @fields

  def changeset(ticker, params \\ %{}) do
    ticker
    |> cast(params, @fields)
    |> validate_required(@required)
  end

  def all_as_maps(fields \\ @fields) do
    Repo.all(from(s in __MODULE__, select: map(s, ^fields)))
  end

  def all_by_exchange(exchange) do
    from(
      q in __MODULE__,
      where: like(q.symbol, ^"#{exchange}:%")
    )
    |> Repo.all()
  end

  def all_by_exchange_and_quote(exchange, quote) do
    from(
      q in __MODULE__,
      where: like(q.symbol, ^"#{exchange}:%:#{quote}")
    )
    |> Repo.all()
  end

  def all_by_base(base) do
    from(
      q in __MODULE__,
      where: like(q.symbol, ^"%:#{base}:%")
    )
    |> Repo.all()
  end

  def all_by_quote(quote) do
    from(
      q in __MODULE__,
      where: like(q.symbol, ^"%:#{quote}")
    )
    |> Repo.all()
  end

  def one_by_symbol(symbol) do
    from(
      q in __MODULE__,
      where: q.symbol == ^symbol
    )
    |> Repo.one()
  end

  #  @fields [:exchange, :base, :quote]
  #  @fields_length length(@fields)
  #  @required @fields
  #
  #  def field_amount, do: @fields_length
  #
  #  def changeset(ticker, params \\ %{}) do
  #    ticker
  #    |> cast(params, @fields)
  #    |> validate_required(@required)
  #  end
  #
  #  def by_exchange(exchange) do
  #    (from t in __MODULE__, where: t.exchange == ^exchange)
  #    |> Repo.all()
  #  end
  #
  #  def count(exchange) do
  #    (from t in __MODULE__, where: t.exchange == ^exchange, select: count(t.id))
  #    |> Repo.one()
  #  end
end
