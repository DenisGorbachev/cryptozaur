defmodule Cryptozaur.Repo.Migrations.AlterOrdersTableRemoveTotalAddDiffsField do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      remove(:total)
      add(:base_diff, :float, null: false)
      add(:quote_diff, :float, null: false)
    end
  end
end
