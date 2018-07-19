defmodule Cryptozaur.Repo.Migrations.AddTradesTable do
  use Ecto.Migration

  def change do
    create table(:trades) do
      add(:uid, :string, null: false)
      add(:symbol, :string, null: false)
      add(:price, :float, null: false)
      add(:amount, :float, null: false)
      add(:timestamp, :naive_datetime, null: false)
    end

    # to search faster
    create(index(:trades, [:symbol, :timestamp], name: "symbol_timestamp_trades_index"))
    create(unique_index(:trades, [:symbol, :uid], name: "symbol_uid_trades_index"))
  end
end
