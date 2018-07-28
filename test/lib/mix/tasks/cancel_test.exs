defmodule Mix.Tasks.Cancel.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can place a cancel order", %{opts: opts} do
    use_cassette "tasks/cancel_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Cancel.run(opts ++ ["leverex", "ETH_D:BTC_D", "16"])

      assert {:ok, uid} = result
      assert uid == "16"

      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, "[UID: 16] Cancelled order")
    end
  end

  test "user can't cancel a non-existent order", %{opts: opts} do
    use_cassette "tasks/cancel_error_order_does_not_exist", match_requests_on: [:query] do
      result = Mix.Tasks.Cancel.run(opts ++ ["leverex", "ETH_D:BTC_D", "256"])

      assert {:error, error} = result

      assert error == %{"details" => %{"id" => 256}, "type" => "not_found"}
      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, "[ERR]")
    end
  end
end
