defmodule Mix.Tasks.Buy.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can place a buy order", %{opts: opts} do
    use_cassette "tasks/buy_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Buy.run(opts ++ ["leverex", "ETH_D:BTC_D", "0.00000001", "20"])

      assert {:ok, order} = result
      assert order.price == 0.00000001
      assert order.amount_requested == 20.0
    end
  end

  test "user can't place a buy order with insufficient funds", %{opts: opts} do
    result = Mix.Tasks.Buy.run(opts ++ ["leverex", "ETH_D:BTC_D", "0.1", "2000000000"])

    assert {:error, %{message: "Insufficient funds"}} = result
  end

  #
  #  test "user can't place a buy order on non-existent market", %{opts: opts} do
  #    result = Mix.Tasks.Buy.run(opts ++ ["leverex", "ULTRATRASH:MEGATRASH", "0.00000001", "20"])
  #  end
end
