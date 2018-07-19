defmodule Cryptozaur.Repo.Migrations.AddTorchesTable do
  use Ecto.Migration

  def change do
    create table(:torches) do
      add(:symbol, :string, null: false)
      add(:open, :float, null: false)
      add(:high, :float, null: false)
      add(:low, :float, null: false)
      add(:close, :float, null: false)
      add(:volume, :float, null: false)
      # in seconds
      add(:resolution, :integer, null: false)
      add(:timestamp, :naive_datetime, null: false)
    end

    # to search faster
    create(unique_index(:torches, [:symbol, :timestamp, :resolution], name: "symbol_timestamp_resolution_torches_index"))
  end
end
