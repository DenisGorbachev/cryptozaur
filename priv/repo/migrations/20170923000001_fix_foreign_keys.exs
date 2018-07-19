defmodule Cryptozaur.Repo.Migrations.FixForeignKeys do
  use Ecto.Migration

  def change do
    drop(constraint(:balances, "balances_account_id_fkey"))

    alter table(:balances) do
      modify(:account_id, references(:accounts, on_delete: :delete_all, on_update: :update_all))
    end

    drop(constraint(:orders, "orders_account_id_fkey"))

    alter table(:orders) do
      modify(:account_id, references(:accounts, on_delete: :delete_all, on_update: :update_all))
    end
  end
end
