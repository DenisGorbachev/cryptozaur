defmodule Mix.Tasks.Show.Withdrawals.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can see his withdraws for the specific asset", %{opts: opts} do
    use_cassette "tasks/show_withdrawals_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Show.Withdrawals.run(opts ++ ["leverex", "ETH_D"])

      assert {:ok, withdrawals} = result
      assert length(withdrawals) == 1

      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, "| 1  | 0.20000000 | 32be343b94f860124dc4fee278fdcbd38c102d88 |")
    end
  end

  test "user can see all active orders in JSON format", %{opts: opts} do
    use_cassette "tasks/show_withdrawals_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Show.Withdrawals.run(opts ++ ["--format", "json", "leverex", "ETH_D"])

      assert {:ok, _} = result
      assert_received {:mix_shell, :info, [msg]}
      assert length(Poison.decode!(msg)) == 1
    end
  end

end
