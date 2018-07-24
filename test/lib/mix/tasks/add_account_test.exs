defmodule Mix.Tasks.Add.AccountTest do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can add account", %{opts: opts, accounts: accounts, accounts_filename: accounts_filename} do
    use_cassette "tasks/add_account_ok", match_requests_on: [:query] do
      File.rm!(accounts_filename)

      result = Mix.Tasks.Add.Account.run(opts ++ [accounts.kucoin.exchange, accounts.kucoin.key, accounts.kucoin.secret])

      assert {:ok, true} = result

      accounts_new = accounts_filename |> File.read!() |> Poison.decode!(keys: :atoms)

      assert accounts_new == %{kucoin: accounts.kucoin}
    end
  end

  test "user can't add account with invalid credential", %{opts: opts, accounts: accounts, accounts_filename: accounts_filename} do
    use_cassette "tasks/add_account_error", match_requests_on: [:query] do
      result = Mix.Tasks.Add.Account.run(opts ++ ["--account", "another_account", "LEVEREX", "wrong_key", "wrong_secret"])

      assert {:error, %{message: "Invalid credentials: request for balances failed", reason: %{"details" => %{"x-key" => "wrong_key", "x-nonce" => _nonce, "x-signature" => _signature, "x-timestamp" => _timestamp}, "type" => "invalid_key"}}} = result

      accounts_new = accounts_filename |> File.read!() |> Poison.decode!(keys: :atoms)

      assert accounts_new == accounts
    end
  end
end
