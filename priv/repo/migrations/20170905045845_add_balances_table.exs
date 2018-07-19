defmodule Cryptozaur.Repo.Migrations.AddBalancesTable do
  use Ecto.Migration

  def change do
    create table(:balances) do
      add(:account_id, references(:accounts, on_delete: :delete_all, on_update: :update_all), null: false)
      add(:currency, :string, null: false)
      add(:amount, :float, null: false)
    end

    create(unique_index(:balances, [:account_id, :currency], name: "account_id_currency_balances_index"))
  end
end
