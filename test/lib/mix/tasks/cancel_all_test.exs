# defmodule Mix.Tasks.Cancel.All.Test do
#  use Cryptozaur.Case, async: true
#  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
#
##  test "user can cancel all orders for all markets", %{opts: opts} do
##     TODO: implement this functionality
##  end
#
#  test "user can cancel all orders for specific market", %{opts: opts} do
##    use_cassette "tasks/cancel_all_ok", match_requests_on: [:query] do
#      for i <- 1..5 do
#        result = Mix.Tasks.Buy.run(opts ++ ["leverex", "ETH_D:BTC_D", "0.00000001", "20"])
#        assert {:ok, _order} = result
#      end
#
#      result = Mix.Tasks.Cancel.All.run(opts ++ ["leverex", "ETH_D:BTC_D"])
#
#      assert {:ok, count} = result
#      assert count == 5
#
#      assert_received {:mix_shell, :info, [msg]}
#      assert String.contains?(msg, "[Count: 5] Cancelled all orders")
##    end
#  end
# end
