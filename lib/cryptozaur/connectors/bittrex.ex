defmodule Cryptozaur.Connectors.Bittrex do
  import OK, only: [success: 1, failure: 1]
  alias Cryptozaur.Model.{Trade, Order, Level, Ticker, Balance}
  alias Cryptozaur.Drivers.BittrexRest, as: Rest

  @btc_dust_threshold 0.00100000

  def credentials_valid?(key, secret) do
    with success(rest) <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest) do
      case Rest.get_balances(rest) do
        success(_) -> success(true)
        failure("APIKEY_INVALID") -> success(false)
        failure("INVALID_SIGNATURE") -> success(false)
        failure(message) -> failure(message)
      end
    end
  end

  # TODO: refactor this function to return %Balance{}
  def get_balance(key, secret, currency) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"Available" => available} <- Rest.get_balance(rest, currency)
    after
      available
    end
  end

  # TODO: test it
  def get_balances(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      balances_raw <- Rest.get_balances(rest)
      balances = Enum.map(balances_raw, &to_balance(&1))
    after
      balances
    end
  end

  # TODO: temp; remove it after Balance model has amount_deposited, amount_available, amount_pending
  def get_balances_as_maps(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      balances_raw <- Rest.get_balances(rest)
      balances = Enum.map(balances_raw, &%{currency: &1["Currency"], amount_deposited: &1["Balance"], amount_available: &1["Available"], amount_pending: &1["Pending"]})
    after
      balances
    end
  end

  def withdraw(key, secret, currency, amount, destination) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      _ <- Rest.withdraw(rest, currency, amount, destination)
    after
      nil
    end
  end

  def get_deposit_address(key, secret, currency, retry \\ true) do
    OK.try do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"Address" => address} <- Rest.get_deposit_address(rest, currency)
    after
      success(address)
    rescue
      "ADDRESS_GENERATING" = message ->
        if retry do
          Process.sleep(2000)
          get_deposit_address(key, secret, currency, false)
        else
          failure(message)
        end

      error ->
        failure(error)
    end
  end

  def get_latest_trades(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      trades <- Rest.get_latest_trades(rest, base, quote)
      symbol = to_symbol(base, quote)
      result = Enum.map(trades, &to_trade(symbol, &1))
    after
      result
    end
  end

  def get_tickers do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      summaries <- Rest.get_summaries(rest)
      result = Enum.map(summaries, &to_ticker/1)
    after
      result
    end
  end

  def place_order(key, secret, base, quote, amount, price, _extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)

      %{"uuid" => uuid} <-
        if amount > 0 do
          Rest.buy_limit(rest, base, quote, amount, price)
        else
          Rest.sell_limit(rest, base, quote, -amount, price)
        end
    after
      uuid
    end
  end

  def cancel_order(key, secret, _base, _quote, uid) do
    OK.try do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      nil <- Rest.cancel(rest, uid)
    after
      success(uid)
    rescue
      "ORDER_NOT_OPEN" ->
        {:error, :order_not_open}
    end
  end

  def get_orders(key, secret, base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      open_orders <- Rest.get_open_orders(rest, base, quote)
      # check that all open_orders have "Closed" => nil
      open_orders |> Enum.each(fn order -> %{"Closed" => nil} = order end)
      closed_orders <- Rest.get_order_history(rest, base, quote)
      result = Enum.map(open_orders, &to_order_from_opened_order/1) ++ Enum.map(closed_orders, &to_order_from_closed_order/1)
    after
      result
    end
  end

  def get_orders(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      open_orders <- Rest.get_open_orders(rest)
      # check that all open_orders have "Closed" => nil
      open_orders |> Enum.each(fn order -> %{"Closed" => nil} = order end)
      closed_orders <- Rest.get_order_history(rest)
      result = Enum.map(open_orders, &to_order_from_opened_order/1) ++ Enum.map(closed_orders, &to_order_from_closed_order/1)
    after
      result
    end
  end

  def get_levels(base, quote, _limit \\ 0) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      symbol = to_symbol(base, quote)
      timestamp = Cryptozaur.Utils.now()
      levels <- Rest.get_order_book(rest, base, quote)
      buys = Enum.map(levels["buy"], &to_level(symbol, 1, timestamp, &1))
      sells = Enum.map(levels["sell"], &to_level(symbol, -1, timestamp, &1))
    after
      {buys, sells}
    end
  end

  defp to_ticker(%{"MarketName" => pair, "Bid" => bid, "Ask" => ask, "BaseVolume" => volume_24h_quote, "Volume" => volume_24h_base}) do
    # Bittrex reports BTC volume as "BaseVolume", while BTC is actually a "quote" currency
    [quote, base] = String.split(pair, "-")
    symbol = to_symbol(base, quote)

    %Ticker{
      symbol: symbol,
      bid: bid,
      ask: ask,
      volume_24h_base: volume_24h_base,
      volume_24h_quote: volume_24h_quote
    }
  end

  defp to_trade(symbol, %{"Id" => id, "TimeStamp" => timestamp_string, "Quantity" => amount, "Price" => price, "OrderType" => type}) do
    sign =
      case type do
        "BUY" -> 1
        "SELL" -> -1
      end

    timestamp = parse_timestamp(timestamp_string)

    %Trade{uid: Integer.to_string(id), symbol: symbol, timestamp: timestamp, amount: amount * sign, price: price}
  end

  defp to_level(symbol, sign, timestamp, %{"Quantity" => amount, "Rate" => price}) do
    %Level{amount: sign * amount, price: price, symbol: symbol, timestamp: timestamp}
  end

  defp to_balance(%{"Currency" => currency, "Balance" => amount_full, "Available" => _amount_available, "Pending" => _amount_pending}) do
    %Balance{currency: currency, amount: amount_full}
  end

  defp to_order_from_closed_order(proto) do
    proto
    |> to_order()
    |> Map.merge(%{status: "closed"})
  end

  defp to_order_from_opened_order(%{"CommissionPaid" => commission, "Opened" => timestamp} = proto) do
    proto
    # align to schema of closed order
    |> Map.merge(%{"TimeStamp" => timestamp, "Commission" => commission})
    |> to_order()
    |> Map.merge(%{status: "opened"})
  end

  defp to_order(
         %{
           "OrderUuid" => uid,
           "Exchange" => bittrex_pair,
           # It looks like Bittrex uses "PricePerUnit" as "actual price that you've got" (in case limit order turned into a market order)
           "Limit" => price_requested,
           "TimeStamp" => timestamp_string,
           "Quantity" => amount_requested,
           "QuantityRemaining" => amount_remaining,
           "Commission" => fee,
           # in fact it's a multiplication of amount & price
           "Price" => amount_multi_price
         } = order
       ) do
    sign = get_sign(order)
    [quote, base] = String.split(bittrex_pair, "-")
    pair = to_pair(base, quote)

    timestamp = parse_timestamp(timestamp_string)
    precision = get_amount_precision(base, quote)
    amount_filled = Float.round(amount_requested - amount_remaining, precision)

    # Bittrex affects quote currency to process fees for both `buy` and `sell` orders
    base_diff = amount_filled * sign
    quote_diff = -1 * sign * amount_multi_price - fee

    %Order{
      uid: uid,
      pair: pair,
      price: price_requested,
      base_diff: base_diff,
      quote_diff: quote_diff,
      amount_requested: amount_requested * sign,
      amount_filled: amount_filled * sign,
      timestamp: timestamp
    }
  end

  defp get_sign(%{"OrderType" => "LIMIT_BUY"}), do: 1
  defp get_sign(%{"OrderType" => "LIMIT_SELL"}), do: -1

  def validate_order(base, quote, amount, price) do
    validate_dust_order(base, quote, amount, price)
  end

  defp validate_dust_order(base, quote, amount, price) do
    if amount * price >= @btc_dust_threshold do
      success(nil)
    else
      min_amount = Float.ceil(@btc_dust_threshold / price, get_amount_precision(base, quote))
      failure([%{key: "amount", message: "Minimum order amount at specified price is #{min_amount} #{base}"}])
    end
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

  def get_link(base, quote) do
    "https://bittrex.com/Market/Index?MarketName=#{quote}-#{base}"
  end

  defp to_symbol(base, quote) do
    "BITTREX:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{base}:#{quote}"
  end

  defp parse_timestamp(string) do
    NaiveDateTime.from_iso8601!(string)
  end
end
