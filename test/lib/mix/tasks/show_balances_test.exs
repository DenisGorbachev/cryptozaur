defmodule Mix.Tasks.Show.BalancesTest do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can see balances", %{opts: opts} do
    use_cassette "tasks/show_balances_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Show.Balances.run(opts ++ ["kucoin"])

      assert {:ok, balances} = result
      assert length(balances) > 0
    end
  end

  test "user can see balance of specific currency", %{opts: opts} do
    use_cassette "tasks/show_balances_ok_specific_currency", match_requests_on: [:query] do
      result = Mix.Tasks.Show.Balances.run(opts ++ ["kucoin", "ACT"])

      assert {:ok, balances} = result
      assert length(balances) == 1
    end
  end
end
