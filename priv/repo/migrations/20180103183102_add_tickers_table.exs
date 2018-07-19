defmodule Cryptozaur.Repo.Migrations.AddTickersTable do
  use Ecto.Migration

  def change do
    create table(:tickers) do
      add(:symbol, :string, null: false)
      add(:bid, :float, null: false)
      add(:ask, :float, null: false)
      # some exchanges provide either volume_24h_base or volume_24h_quote
      add(:volume_24h_base, :float, null: true)
      # some exchanges provide either volume_24h_base or volume_24h_quote
      add(:volume_24h_quote, :float, null: true)
      timestamps()
    end

    create(unique_index(:tickers, [:symbol], name: "symbol_tickers_unique_index"))
  end
end
