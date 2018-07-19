defmodule Cryptozaur.Connectors.Bithumb do
  import OK, only: [success: 1]

  import Cryptozaur.Utils

  alias Cryptozaur.Model.{Ticker, Trade, Order, Balance}
  alias Cryptozaur.Drivers.BithumbRest, as: Rest

  def get_ticker(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      ticker_raw <- Rest.get_ticker(rest, base, quote)
    after
      to_ticker(ticker_raw, base)
    end
  end

  def get_tickers() do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      tickers_raw <- Rest.get_tickers(rest)

      result =
        tickers_raw
        |> Enum.filter(&(elem(&1, 0) != "date"))
        |> Enum.map(&to_ticker_map/1)
    after
      result
    end
  end

  # this function is to fix some inconsistencies between api v1 and v2
  defp to_ticker_map(ticker) do
    {base, ticker} = ticker
    to_ticker(ticker, base)
  end

  defp to_ticker(%{"buy_price" => bid, "sell_price" => ask, "volume_1day" => volume_24h_base}, base) do
    %Ticker{
      symbol: to_symbol(base),
      bid: to_float(bid),
      ask: to_float(ask),
      volume_24h_base: to_float(volume_24h_base),
      # Bithumb doesn't provide it
      volume_24h_quote: nil
    }
  end

  defp to_symbol(base) do
    # Bithumb has only KRW pairs now
    "BITHUMB:#{to_pair(base, "KRW")}"
  end

  defp to_pair(base, quote) do
    "#{String.upcase(base)}:#{String.upcase(quote)}"
  end
end
