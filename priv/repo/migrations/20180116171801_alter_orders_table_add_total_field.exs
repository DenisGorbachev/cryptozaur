defmodule Cryptozaur.Repo.Migrations.AlterOrdersTableAddTotalField do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:total, :float, default: 0.0)
    end
  end
end
