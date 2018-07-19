defmodule Cryptozaur.Connectors.Coinmarketcap do
  require OK
  import Cryptozaur.Utils
  alias Cryptozaur.Drivers.CoinmarketcapRest, as: Rest

  def get_briefs(opts \\ %{limit: 0}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      briefs <- Rest.get_briefs(rest, opts)
      result = briefs |> Enum.map(&to_brief/1)
    after
      result
    end
  end

  defp to_brief(%{"symbol" => asset, "id" => coinmarketcap_id, "24h_volume_usd" => volume_24h_USD, "market_cap_usd" => market_cap_USD} = _brief) do
    %{
      asset: asset,
      coinmarketcap_id: coinmarketcap_id,
      link: "https://coinmarketcap.com/currencies/#{coinmarketcap_id}/",
      volume_24h_USD: to_float(default(volume_24h_USD, 0.0)),
      market_cap_USD: to_float(default(market_cap_USD, 0.0)),
      is_complete: !is_nil(volume_24h_USD) and !is_nil(market_cap_USD)
    }
  end
end
