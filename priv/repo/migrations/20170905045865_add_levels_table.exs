defmodule Cryptozaur.Repo.Migrations.AddLevelsTable do
  use Ecto.Migration

  def change do
    create table(:levels) do
      add(:symbol, :string, null: false)
      add(:price, :float, null: false)
      add(:amount, :float, null: false)
      add(:timestamp, :naive_datetime, null: false)
    end

    # to search faster
    create(index(:levels, [:timestamp], name: "timestamp_levels_index"))
  end
end
