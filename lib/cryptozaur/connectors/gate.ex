defmodule Cryptozaur.Connectors.Gate do
  require OK
  import Cryptozaur.Utils

  alias Cryptozaur.Model.Ticker
  alias Cryptozaur.Drivers.GateRest, as: Rest

  def get_tickers do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      summaries <- Rest.get_tickers(rest)
      result = Enum.map(summaries, &to_ticker/1)
    after
      result
    end
  end

  def get_ticker(base, quote) do
    OK.for do
      tickers <- get_tickers()
    after
      Enum.find(tickers, &(&1.symbol == to_symbol(base, quote)))
    end
  end

  def get_balance do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      balance <- Rest.get_balance(rest)
    after
      balance
    end
  end

  defp to_ticker({name_key, %{"highestBid" => bid, "lowestAsk" => ask, "quoteVolume" => volume_24h_quote, "baseVolume" => volume_24h_base}}) do
    [base, quote] = String.upcase(name_key) |> String.split("_")

    %Ticker{
      symbol: to_symbol(base, quote),
      bid: to_float(bid),
      ask: to_float(ask),
      volume_24h_base: to_float(volume_24h_base),
      volume_24h_quote: to_float(volume_24h_quote)
    }
  end

  defp to_symbol(base, quote) do
    "GATE:#{base}:#{quote}"
  end

  def get_amount_precision(base, _quote) do
    case base do
      _ -> 8
    end
  end

  def get_price_precision(_base, quote) do
    case quote do
      _ -> 8
    end
  end

  def get_tick(_base, quote) do
    case quote do
      _ -> 0.00000001
    end
  end

  def get_link(base, quote) do
    "https://gate.io/trade/#{String.downcase(base)}_#{String.downcase(quote)}"
  end
end
