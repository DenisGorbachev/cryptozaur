defmodule Mix.Tasks.Add.AccountTest do
  use ExUnit.Case, async: true

  @tag config: %{}
  setup context do
    {:ok, config_filename} = Briefly.create()
    File.write!(config_filename, Poison.encode!(context[:config]))
    {:ok, accounts_filename} = Briefly.create()
    File.write!(accounts_filename, Poison.encode!(context[:accounts]))
    context
    |> Map.put(:opts, ["--config", config_filename, "--accounts", accounts_filename])
  end

#  test "adds account", %{opts: opts} do
  #    use_cassette "leverex/get_balances", match_requests_on: [:query] do
#    Mix.Tasks.Add.Account.run(opts ++ ["kucoin KUCOIN "])
#
#    assert_received {:mix_shell, :info, [jwt]}
#end
#  end

end
