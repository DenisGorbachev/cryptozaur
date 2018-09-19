defmodule Mix.Tasks.Withdraw.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can withdraw some asset to the specific address", %{opts: opts} do
    use_cassette "tasks/withdraw_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Withdraw.run(opts ++ ["leverex", "ETH_D", "32be343b94f860124dc4fee278fdcbd38c102d88", "0.2"])

      assert {:ok, withdrawal_id} = result
      assert withdrawal_id

      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, "[Withdrawal ID: #{withdrawal_id}]")
    end
  end

  test "user can withdraw some asset to the specific address in JSON format", %{opts: opts} do
    use_cassette "tasks/withdraw_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Withdraw.run(opts ++ ["leverex", "ETH_D", "32be343b94f860124dc4fee278fdcbd38c102d88", "0.2"])

      assert {:ok, withdrawal_id} = result
      assert withdrawal_id

      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, ~s|[Withdrawal ID: #{withdrawal_id}]|)
    end
  end

end
