defmodule Mix.Tasks.Add.AccountTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  setup context do
    config = context[:config] || %{}
    accounts = context[:accounts] || %{}
    [key: key, secret: secret] = Application.get_env(:cryptozaur, :kucoin, key: "", secret: "")
    accounts = accounts |> Map.put(:kucoin, %{exchange: "KUCOIN", key: key, secret: secret})
    context = context |> Map.put(:config, config)
    context = context |> Map.put(:accounts, accounts)

    {:ok, config_filename} = Briefly.create()
    File.write!(config_filename, Poison.encode!(context[:config]))
    {:ok, accounts_filename} = Briefly.create()
    File.write!(accounts_filename, Poison.encode!(context[:accounts]))

    context
    |> Map.put(:opts, ["--config", config_filename, "--accounts", accounts_filename])
    |> Map.put(:config, config)
    |> Map.put(:accounts, accounts)
    |> Map.put(:config_filename, config_filename)
    |> Map.put(:accounts_filename, accounts_filename)
  end

  test "user can add account", %{opts: opts, accounts: accounts, accounts_filename: accounts_filename} do
    use_cassette "tasks/add_account_ok", match_requests_on: [:query] do
      File.rm!(accounts_filename)

      result = Mix.Tasks.Add.Account.run(opts ++ [accounts.kucoin.exchange, accounts.kucoin.key, accounts.kucoin.secret])

      assert result == {:ok, true}

      accounts_new = accounts_filename |> File.read!() |> Poison.decode!(keys: :atoms)

      assert accounts_new == accounts
    end
  end

  test "user can't add account with invalid credential", %{opts: opts, accounts: accounts, accounts_filename: accounts_filename} do
    use_cassette "tasks/add_account_error", match_requests_on: [:query] do
      result = Mix.Tasks.Add.Account.run(opts ++ ["--name", "another_account", "LEVEREX", "wrong_key", "wrong_secret"])

      assert {:error, %{message: "Invalid credentials: request for balances failed", reason: %{"details" => %{"x-key" => "wrong_key", "x-nonce" => _nonce, "x-signature" => _signature, "x-timestamp" => _timestamp}, "type" => "invalid_key"}}} = result

      accounts_new = accounts_filename |> File.read!() |> Poison.decode!(keys: :atoms)

      assert accounts_new == accounts
    end
  end
end
