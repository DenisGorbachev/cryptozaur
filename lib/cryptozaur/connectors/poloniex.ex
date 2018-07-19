defmodule Cryptozaur.Connectors.Poloniex do
  import Logger
  import OK, only: [success: 1]
  require OK

  import Cryptozaur.Utils
  alias Cryptozaur.Model.{Trade}
  alias Cryptozaur.Drivers.PoloniexRest, as: Rest

  # the worst case - February
  @iterate_trades_period 3600 * 24 * 28
  @btc_dust_threshold 0.0001000

  def get_trades(base, quote, from, to, _extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      trades <- Rest.get_trade_history(rest, base, quote, from, to)
      symbol = to_symbol(base, quote)
      result = Enum.map(trades, &to_trade(symbol, &1))
    after
      result
    end
  end

  def iterate_trades(base, quote, from, to, {module, function, arguments} = callback) do
    debug(">> Poloniex.iterate_trades(#{inspect(base)}, #{inspect(quote)}, #{inspect(from)}, #{inspect(to)}, callback)")

    # it's not allowed to request too wide ranges
    farthest_from = NaiveDateTime.add(to, -@iterate_trades_period)
    valid_from = max_date(from, farthest_from)

    success(trades) = get_trades(base, quote, valid_from, to)
    apply(module, function, arguments ++ [trades])

    debug("~~ Poloniex.iterate_trades(#{inspect(base)}, #{inspect(quote)}, #{inspect(from)}, #{inspect(to)}, callback) # fetched #{length(trades)} trades")

    if fetch_more?(trades) do
      last_timestamp = List.last(trades).timestamp
      iterate_trades(base, quote, from, last_timestamp, callback)
    end
  end

  def fetch_more?(trades) do
    # Don't check if length(trades) < 50000: Poloniex might change this limit
    length(trades) != 0 and List.first(trades).timestamp != List.last(trades).timestamp
  end

  def get_min_price(_base, quote) do
    case quote do
      "BTC" -> 0.00000001
      "ETH" -> 0.00000001
      "USDT" -> 0.00000001
    end
  end

  def get_min_amount(base, price) do
    case base do
      _ -> @btc_dust_threshold / price
    end
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

  defp to_trade(symbol, %{
         "globalTradeID" => uid,
         "date" => timestamp_string,
         "type" => type,
         "rate" => price_string,
         "amount" => amount_string
       }) do
    sign =
      case type do
        "buy" -> 1
        "sell" -> -1
      end

    uid_string = Integer.to_string(uid)
    price = String.to_float(price_string)
    timestamp = parse_time(timestamp_string)
    amount = String.to_float(amount_string)

    %Trade{
      uid: uid_string,
      symbol: symbol,
      price: price,
      amount: amount * sign,
      timestamp: timestamp
    }
  end

  defp to_symbol(base, quote) do
    "POLONIEX:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{base}:#{quote}"
  end

  defp parse_time(string) do
    NaiveDateTime.from_iso8601!(string)
  end
end
