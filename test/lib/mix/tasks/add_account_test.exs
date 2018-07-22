defmodule Mix.Tasks.Add.AccountTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  @tag config: %{}, accounts: %{}
  setup context do
    [key: key, secret: secret] = Application.get_env(:cryptozaur, :kucoin, key: "", secret: "")
    {:ok, config_filename} = Briefly.create()
    File.write!(config_filename, Poison.encode!(context[:config]))
    {:ok, accounts_filename} = Briefly.create()

    File.write!(
      accounts_filename,
      Poison.encode!(
        context[:accounts]
        |> Map.put(:kucoin, %{
          exchange: "KUCOIN",
          key: key,
          secret: secret
        })
      )
    )

    context
    |> Map.put(:opts, ["--config", config_filename, "--accounts", accounts_filename])
  end

  test "adds account", %{opts: opts} do
    use_cassette "tasks/add_account", match_requests_on: [:query] do
      accounts_filename = List.last(opts)
      accounts = accounts_filename |> File.read!() |> Poison.decode!(keys: :atoms)
      File.rm!(accounts_filename)

      result = Mix.Tasks.Add.Account.run(opts ++ [accounts.kucoin.exchange, accounts.kucoin.key, accounts.kucoin.secret])

      assert result == {:ok, true}

      accounts_new = accounts_filename |> File.read!() |> Poison.decode!(keys: :atoms)

      assert accounts_new == accounts
    end
  end
end
