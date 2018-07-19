defmodule Cryptozaur.Repo.Migrations.AddOrdersTable do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add(:account_id, references(:accounts, on_delete: :delete_all, on_update: :update_all), null: false)
      add(:uid, :string, null: false)
      add(:pair, :string, null: false)
      add(:price, :float, null: false)
      add(:amount_requested, :float, null: false)
      add(:amount_filled, :float, null: false)
      add(:status, :string, null: false)
      add(:timestamp, :naive_datetime, null: false)
      timestamps()
    end

    create(unique_index(:orders, [:account_id, :uid], name: "account_id_uid_orders_index"))
  end
end
