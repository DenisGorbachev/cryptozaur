defmodule Cryptozaur.Repo.Migrations.AddAccountsTable do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add(:exchange, :string, null: false)
      add(:key, :string, null: false)
      add(:secret, :string, null: false)
      timestamps()
    end

    create(unique_index(:accounts, [:exchange, :key], name: "exchange_key_accounts_index"))
  end
end
