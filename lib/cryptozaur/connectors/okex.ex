defmodule Cryptozaur.Connectors.Okex do
  require OK

  import Cryptozaur.Utils

  alias Cryptozaur.Model.{Ticker, Balance}
  alias Cryptozaur.Drivers.OkexRest, as: Rest

  def get_ticker(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      ticker <- Rest.get_ticker(rest, base, quote)
      %{"ticker" => ticker_raw} = ticker
    after
      to_ticker(ticker_raw, base, quote)
    end
  end

  def get_tickers() do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      ticker_raw <- Rest.get_tickers(rest)
      result = Enum.map(ticker_raw, &fix_ticker/1)
    after
      result
    end
  end

  def get_balances(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      result <- Rest.get_userinfo(rest)
      funds = result["info"]["funds"]
      currencies = Map.keys(funds["free"])
      balances = currencies |> Enum.map(&to_balance(&1, funds))
    after
      balances
    end
  end

  def place_order(key, secret, base, quote, amount, price, _extra \\ %{}) do
    type =
      if amount > 0 do
        "buy"
      else
        "sell"
      end

    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"order_id" => uid} <- Rest.trade(rest, String.downcase("#{base}_#{quote}"), type, abs(amount), price)
    after
      to_string(uid)
    end
  end

  def cancel_order(key, secret, base, quote, uid, _extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"order_id" => uid} <- Rest.cancel_order(rest, String.downcase("#{base}_#{quote}"), uid)
    after
      # already a string
      uid
    end
  end

  def get_min_amount(base, _price) do
    case base do
      # TODO: find out real min_amount
      _ ->
        0.01
    end
  end

  def get_amount_precision(base, quote) do
    case base do
      _ ->
        case quote do
          "USDT" -> 3
          _ -> 8
        end
    end
  end

  def get_price_precision(_base, quote) do
    case quote do
      "USDT" -> 8
      _ -> 8
    end
  end

  # this function is to fix some inconsistencies between api v1 and v2
  defp fix_ticker(ticker) do
    [base, quote] = ticker["symbol"] |> String.split("_")
    ticker = Map.put(ticker, "vol", ticker["volume"])
    to_ticker(ticker, base, quote)
  end

  defp to_ticker(%{"buy" => bid, "sell" => ask, "vol" => volume_24h_base}, base, quote) do
    %Ticker{
      symbol: to_symbol(base, quote),
      bid: to_float(bid),
      ask: to_float(ask),
      volume_24h_base: to_float(volume_24h_base),
      # OKEx doesn't provide it
      volume_24h_quote: nil
    }
  end

  defp to_balance(currency, funds) do
    %Balance{currency: String.upcase(currency), amount: to_float(funds["free"][currency])}
  end

  defp to_symbol(base, quote) do
    "OKEX:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{String.upcase(base)}:#{String.upcase(quote)}"
  end
end
