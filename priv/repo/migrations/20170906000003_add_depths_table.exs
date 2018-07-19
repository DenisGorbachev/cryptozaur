defmodule Cryptozaur.Repo.Migrations.AddDepthsTable do
  use Ecto.Migration

  def change do
    create table(:depths) do
      add(:symbol, :string, null: false)
      add(:buys, :float, null: false)
      add(:sells, :float, null: false)
      add(:timestamp, :naive_datetime, null: false)
    end

    # to search faster
    create(unique_index(:depths, [:symbol, :timestamp], name: "symbol_timestamp_depths_index"))
  end
end
