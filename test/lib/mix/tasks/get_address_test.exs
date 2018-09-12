defmodule Mix.Tasks.Get.Address.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can get a deposit address for the specific currency", %{opts: opts} do
    use_cassette "tasks/get_address_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Get.Address.run(opts ++ ["leverex", "ETH_T"])

      assert {:ok, address} = result
      assert address == "8005b9ad313bd32118809d12dedb0c39eac1adda"

      assert_received {:mix_shell, :info, [msg]}
      assert String.contains?(msg, "[Deposit address: 8005b9ad313bd32118809d12dedb0c39eac1adda]")
    end
  end
end
