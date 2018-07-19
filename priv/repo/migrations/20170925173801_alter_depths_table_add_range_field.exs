defmodule Cryptozaur.Repo.Migrations.AlterDepthsTableAddRangeField do
  use Ecto.Migration

  def change do
    alter table(:depths) do
      add(:range, :float, null: false, default: 0.2)
    end
  end
end
