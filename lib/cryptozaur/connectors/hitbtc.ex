defmodule Cryptozaur.Connectors.Hitbtc do
  require OK
  import OK, only: [success: 1, failure: 1]
  import Cryptozaur.Utils
  import Cryptozaur.Logger
  alias Cryptozaur.Model.{Ticker, Trade}
  alias Cryptozaur.Drivers.HitbtcRest, as: Rest

  # actually, I was able to place an order with total = 0.00000329 (less than @btc_dust_threshold)
  @btc_dust_threshold 0.00001000

  def get_trades(base, quote, from \\ nil, to \\ nil, extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      trades <- Rest.get_trades(rest, base, quote, from, to, extra)
      symbol = to_symbol(base, quote)
      result = Enum.map(trades, &to_trade(&1, symbol))
    after
      result
    end
  end

  def iterate_trades(base, quote, from, to, callback) do
    debug_enter(%{base: base, quote: quote, from: from, to: to})

    do_iterate_trades(base, quote, from, to, callback)

    debug_exit()
  end

  defp do_iterate_trades(base, quote, from, to, callback) do
    # it's not allowed to request too wide ranges
    #    farthest_to = NaiveDateTime.add(from, @iterate_trades_period)
    #    valid_to = min_date(to, farthest_to)

    by = (is_binary(to) && "id") || "timestamp"
    success(trades) = get_trades(base, quote, from, to, %{order: "DESC", by: by, limit: 1000})
    first_trade = List.first(trades)
    last_trade = List.last(trades)

    if is_function(callback) do
      callback.(trades)
    else
      {module, function, arguments} = callback
      apply(module, function, arguments ++ [trades])
    end

    debug_step(%{to: to, to_timestamp: first_trade.timestamp, trades: length(trades)})

    if first_trade.uid != last_trade.uid do
      do_iterate_trades(base, quote, from, last_trade.uid, callback)
    else
      if date_gt(last_trade.timestamp, from), do: warn_step(%{message: "Last trade timestamp is later than `from` timestamp", last_trade_timestamp: last_trade.timestamp, from: from})
    end
  end

  defp to_trade(%{"id" => uid, "side" => side, "quantity" => amount, "price" => price, "timestamp" => timestamp}, symbol) do
    %Trade{
      uid: to_string(uid),
      symbol: symbol,
      price: to_float(price),
      amount: to_float(amount) * ((side == "buy" && 1.0) || -1.0),
      timestamp: NaiveDateTime.from_iso8601!(timestamp)
    }
  end

  defp to_symbol(base, quote) do
    "HITBTC:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{String.upcase(base)}:#{String.upcase(quote)}"
  end

  #  defp parse_timestamp(string) do
  #    NaiveDateTime.from_iso8601!(string)
  #  end
  #
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

  def get_price_precision(base, quote) do
    case base do
      "STORM" ->
        case quote do
          _ -> 7
        end

      _ ->
        8
    end
  end

  def get_tick(_base, quote) do
    case quote do
      _ -> 0.00000001
    end
  end
end
