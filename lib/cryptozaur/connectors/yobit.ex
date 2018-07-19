# Rate limit: 100 req/min (~1.6 req/sec)
defmodule Cryptozaur.Connectors.Yobit do
  import OK, only: [success: 1, failure: 1]

  alias Cryptozaur.Drivers.YobitRest, as: Rest

  def credentials_valid?(key, secret) do
    with success(rest) <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest) do
      case Rest.get_info(rest) do
        success(_) -> success(true)
        failure("invalid key, sign, method or nonce") -> success(false)
        failure(message) -> failure(message)
      end
    end
  end

  #  def pair_valid?(base, quote) do
  #    with success(rest) <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
  #    do
  #      case Rest.get_order_book(rest, base, quote) do
  #        success(_) -> success(true)
  #        failure("INVALID_MARKET") -> success(false)
  #        failure(message) -> failure(message)
  #      end
  #    end
  #  end

  #  def get_latest_trades(base, quote) do
  #    OK.for do
  #      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
  #      trades <- Rest.get_latest_trades(rest, base, quote)
  #      symbol = to_symbol(base, quote)
  #      result = Enum.map trades, &(to_trade(symbol, &1))
  #    after
  #      result
  #    end
  #  end
  #
  #  def place_order(key, secret, base, quote, amount, price, extra \\ %{}) do
  #    OK.for do
  #      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
  #      %{"uuid" => uuid} <- if amount > 0 do
  #        Rest.buy_limit(rest, base, quote, amount, price)
  #      else
  #        Rest.sell_limit(rest, base, quote, -amount, price)
  #      end
  #    after
  #      uuid
  #    end
  #  end
  #
  #  def cancel_order(key, secret, uid) do
  #    OK.try do
  #      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
  #      nil <- Rest.cancel(rest, uid)
  #    after
  #      success(uid)
  #    rescue
  #      "ORDER_NOT_OPEN" ->
  #        {:error, :order_not_open}
  #    end
  #  end
  #
  #  def get_orders(key, secret) do
  #    OK.for do
  #      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
  #      info <- Rest.get_info(rest)
  #      result = info["orders"]
  #      # check that all open_orders have "Closed" => nil
  ##      orders |> Enum.each(fn(order) -> %{"Closed" => nil} = order end)
  ##      closed_orders <- Rest.get_order_history(rest)
  ##      result =
  ##        Enum.map(open_orders, &to_order_from_opened_order/1)
  ##        ++
  ##        Enum.map(closed_orders, &to_order_from_closed_order/1)
  #    after
  #      result
  #    end
  #  end
  #
  #  def get_levels(base, quote) do
  #    OK.for do
  #      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
  #      levels <- Rest.get_order_book(rest, base, quote)
  #      symbol = to_symbol(base, quote)
  #
  #      timestamp = Cryptozaur.Utils.now()
  #
  #      buys = Enum.map(levels["buy"], &(to_level(symbol, 1, timestamp, &1)))
  #      sells = Enum.map(levels["sell"], &(to_level(symbol, -1, timestamp, &1)))
  #    after
  #      {buys, sells}
  #    end
  #  end
  #
  #  defp to_trade(symbol, %{"Id" => id, "TimeStamp" => timestamp_string, "Quantity" => amount, "Price" => price, "OrderType" => type}) do
  #    sign = case type do
  #      "BUY" -> 1
  #      "SELL" -> -1
  #    end
  #
  #    timestamp = parse_timestamp(timestamp_string)
  #
  #    %Trade{uid: Integer.to_string(id), symbol: symbol, timestamp: timestamp, amount: amount * sign, price: price}
  #  end
  #
  #  defp to_level(symbol, sign, timestamp, %{"Quantity" => amount, "Rate" => price}) do
  #    %Level{price: price, amount: sign * amount, symbol: symbol, timestamp: timestamp}
  #  end
  #
  #  defp to_order_from_closed_order(proto) do
  #    order = to_order(proto)
  #    Map.put(order, :status, "closed")
  #  end
  #
  #  defp to_order_from_opened_order(proto) do
  #    proto = Map.put(proto, "TimeStamp", proto["Opened"])
  #    order = to_order(proto)
  #    Map.put(order, :status, "opened")
  #  end
  #
  #  defp to_order(%{
  #    "OrderUuid" => uid,
  #    "Exchange" => pair_in_yobit_format,
  #    "Limit" => price, # It looks like Yobit uses "PricePerUnit" as "actual price that you've got" (in case limit order turned into a market order)
  #    "TimeStamp" => timestamp_string,
  #    "Quantity" => amount_requested,
  #    "QuantityRemaining" => amount_remaining,
  #    "OrderType" => type
  #  }) do
  #    sign = case type do
  #      "LIMIT_BUY" -> 1
  #      "LIMIT_SELL" -> -1
  #    end
  #
  #    [quote, base] = String.split(pair_in_yobit_format, "-")
  #    pair = to_pair(base, quote)
  #
  #    timestamp = parse_timestamp(timestamp_string)
  #    amount_filled = amount_requested - amount_remaining
  #
  #    %Order{
  #      uid: uid,
  #      pair: pair,
  #      price: price,
  #      amount_requested: amount_requested * sign,
  #      amount_filled: amount_filled * sign,
  #      status: "closed",
  #      timestamp: timestamp
  #    }
  #  end
  #
  #  def validate_order(_base, quote, price, amount) do
  #    validate_dust_order(quote, price, amount)
  #  end
  #
  #  defp validate_dust_order("BTC" = base, price, amount) do
  #    if price * amount >= @btc_dust_threshold do
  #      success(nil)
  #    else
  #      min = Float.ceil(@btc_dust_threshold / price, get_amount_precision(base))
  #      failure([%{key: "amount", message: "Minimum order amount at specified price is #{min} #{base}"}])
  #    end
  #  end
  #
  #  defp validate_dust_order(_base, _price, _amount) do
  #    success(nil)
  #    # raise ~s'validate_order does NOT support "#{base}" quote'
  #  end

  def get_min_price(_base, quote) do
    case quote do
      "BTC" -> 0.00000001
      "ETH" -> 0.00000001
      "USDT" -> 0.00000001
    end
  end

  def get_min_amount(base, price) do
    # DUST_TRADE_DISALLOWED_MIN_VALUE_50K_SAT
    case base do
      _ -> 0.00050000 / price
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

  def get_link(base, quote) do
    "https://yobit.com/Market/Index?MarketName=#{quote}-#{base}"
  end

  #  defp to_symbol(base, quote) do
  #    "YOBIT:#{to_pair(base, quote)}"
  #  end

  #  defp to_pair(base, quote) do
  #    "#{base}:#{quote}"
  #  end

  #  defp parse_timestamp(string) do
  #    NaiveDateTime.from_iso8601!(string)
  #  end
end
