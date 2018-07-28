defmodule Mix.Tasks.Sell.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can place a sell order", %{opts: opts} do
    use_cassette "tasks/sell_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Sell.run(opts ++ ["leverex", "ETH_D:BTC_D", "0.5", "20"])

      assert {:ok, order} = result
      assert order.price == 0.5
      assert order.amount_requested == -20.0
    end
  end

  test "user can't place a sell order with insufficient funds", %{opts: opts} do
    result = Mix.Tasks.Sell.run(opts ++ ["leverex", "ETH_D:BTC_D", "0.5", "20000000"])

    assert {:error, %{message: "Insufficient funds"}} = result
  end

  test "user can't place a sell order on non-existent market", %{opts: opts} do
    use_cassette "tasks/sell_error_invalid_symbol", match_requests_on: [:query] do
      result = Mix.Tasks.Sell.run(opts ++ ["leverex", "ULTRATRASH:MEGATRASH", "0.00000001", "20"])

      assert {:error, error} = result

      assert error == %{
               "details" => %{"symbol" => "ULTRATRASH:MEGATRASH"},
               "type" => "invalid_symbol"
             }
    end
  end
end
