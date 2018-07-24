defmodule Mix.Tasks.Show.Info.Test do
  use Cryptozaur.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]

  test "user can see exchange info", %{opts: opts} do
    use_cassette "tasks/show_info_ok", match_requests_on: [:query] do
      result = Mix.Tasks.Show.Info.run(opts ++ ["leverex"])

      assert {:ok, info} = result
      assert %{"markets" => %{}, "assets" => %{}} = info
    end
  end
end
