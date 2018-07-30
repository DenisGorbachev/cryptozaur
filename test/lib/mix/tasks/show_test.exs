defmodule Mix.Tasks.Show.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  alias Cryptozaur.Model.Order

  test "user can see all active orders", %{opts: opts} do
    use_cassette "tasks/show_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Show.run(opts ++ ["leverex"])

      assert {:ok, orders} = result
      assert [%Order{} | _] = orders
      assert length(orders) == 1201

      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, "| O | + | 0.00000001 | 0.00000000 | 0.00000001 | ~N[2018-07-30 09:01:10.836952] | 418  |")
    end
  end

  test "user can see all active orders in JSON format", %{opts: opts} do
    use_cassette "tasks/show_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Show.run(opts ++ ["--format", "json", "leverex"])

      assert {:ok, _} = result
      assert_received {:mix_shell, :info, [msg]}
      assert length(Poison.decode!(msg)) == 1201
    end
  end

  #  test "user can see his orders placed on a specific market", %{opts: opts} do
  #    #    use_cassette "tasks/show_ok_specific_market", match_requests_on: [:query] do
  #    result = Mix.Tasks.Show.run(opts ++ ["leverex", "ETH_D:BTC_D"])
  #
  #    assert {:ok, uid} = result
  #    assert uid == "16"
  #
  #    assert_received {:mix_shell, :info, [msg]}
  #    assert String.contains?(msg, "[UID: 16] showled order")
  #    #    end
  #  end
end
