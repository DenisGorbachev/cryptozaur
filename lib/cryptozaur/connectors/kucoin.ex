defmodule Cryptozaur.Connectors.Kucoin do
  require OK
  import Cryptozaur.Utils
  alias Cryptozaur.Model.{Ticker, Balance, Order}
  alias Cryptozaur.Drivers.KucoinRest, as: Rest
  alias Cryptozaur.Connector

  def get_ticker(base, quote) do
    OK.for do
      tickers <- get_tickers()
      result = tickers |> Enum.find(&(&1.symbol == to_symbol(base, quote)))
    after
      result
    end
  end

  def get_tickers(_extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      tickers <- Rest.get_tickers(rest)
      # If the trading on a new pair hasn't started yet, Kucoin provides a ticker with `nil` in "buy" and "sell" fields
      tickers = tickers |> Enum.map(&fix_ticker/1)
      # Sometimes Kucoin returns the same symbol twice
      tickers = tickers |> Enum.uniq_by(& &1["symbol"])
      result = Enum.map(tickers, &to_ticker/1)
    after
      result
    end
  end

  def get_balance(key, secret, currency) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      result <- Rest.get_balance(rest, currency)
      balance = to_balance(result)
    after
      balance
    end
  end

  def get_balances(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"datas" => datas} <- Rest.get_balances(rest)
      balances = Enum.map(datas, &to_balance(&1))
    after
      balances
    end
  end

  def place_order(key, secret, base, quote, amount, price, _extra \\ %{}) do
    type =
      if amount <= 0 do
        "SELL"
      else
        "BUY"
      end

    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"orderOid" => uuid} <- Rest.create_order(rest, "#{base}-#{quote}", abs(amount), price, type)
    after
      uuid
    end
  end

  def cancel_order(key, secret, base, quote, orderOid, type, _extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      result <- Rest.cancel_order(rest, "#{base}-#{quote}", orderOid, type)
    after
      result
    end
  end

  def get_orders(key, secret, _extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"BUY" => buy_orders_data, "SELL" => sell_orders_data} <- Rest.get_open_orders(rest)
      %{"datas" => closed_orders_data} <- Rest.get_closed_orders(rest)
    after
      opened_orders = Enum.map(buy_orders_data ++ sell_orders_data, &to_order_from_opened_order/1)
      closed_orders = Enum.map(closed_orders_data, &to_order_from_closed_order/1)
      opened_orders ++ closed_orders
    end
  end

  defp fix_ticker(ticker) do
    ticker
    |> Map.put("buy", ticker["buy"] || 0.0)
    |> Map.put("sell", ticker["sell"] || 0.0)
  end

  defp to_ticker(%{"symbol" => pair, "buy" => bid, "sell" => ask, "vol" => volume_24h_base, "volValue" => volume_24h_quote}) do
    [base, quote] = String.split(pair, "-")
    symbol = to_symbol(base, quote)
    #    if pair == "TEL-USDT", do: Apex.ap(ticker, numbers: false)
    #    if !is_number(bid), do: raise "Invalid bid in ticker: #{inspect(ticker)}"
    %Ticker{
      symbol: symbol,
      bid: to_float(bid),
      ask: to_float(ask),
      volume_24h_base: to_float(volume_24h_base),
      volume_24h_quote: to_float(volume_24h_quote)
    }
  end

  defp to_order_from_closed_order(%{"amount" => amount_unsigned, "dealValue" => quote_affected, "dealPrice" => price, "fee" => fee} = data) do
    sign = get_sign(data)
    amount = amount_unsigned * sign
    base_diff = amount - if sign == -1, do: 0, else: fee
    quote_diff = -1 * (sign * quote_affected - if sign == -1, do: fee, else: 0)

    to_order(data)
    |> Map.merge(%{
      base_diff: base_diff,
      quote_diff: quote_diff,
      amount_requested: amount,
      amount_filled: amount,
      price: price,
      status: "closed"
    })
  end

  defp to_order_from_opened_order(%{"pendingAmount" => amount_remaining_unsigned, "dealAmount" => amount_filled_unsigned, "price" => price} = data) do
    # TODO move get_fee from Connector attributes to exchange implementations (Bittrex, Kucoin etc.)
    # using :taker fee to account for the worst case (market-fill due to race condition)
    fee = Connector.get_fee("KUCOIN", nil, nil, :taker)

    sign = get_sign(data)
    amount_requested = (amount_filled_unsigned + amount_remaining_unsigned) * sign
    amount_filled = amount_filled_unsigned * sign
    base_diff = amount_filled * if sign == -1, do: 1, else: 1 - fee
    quote_diff = -1 * amount_filled * price * if sign == -1, do: 1 - fee, else: 1

    to_order(data)
    |> Map.merge(%{
      base_diff: base_diff,
      quote_diff: quote_diff,
      amount_requested: amount_requested,
      amount_filled: amount_filled,
      price: price,
      status: "opened"
    })
  end

  defp to_order(
         %{
           "oid" => uid,
           "coinType" => base,
           "coinTypePair" => quote,
           "createdAt" => timestamp_in_milliseconds
         } = _order
       ) do
    pair = to_pair(base, quote)
    timestamp = timestamp_in_milliseconds |> DateTime.from_unix!(:millisecond) |> DateTime.to_naive()

    %Order{
      uid: uid,
      pair: pair,
      timestamp: timestamp
    }
  end

  defp to_balance(%{"coinType" => currency, "balance" => balance}) do
    %Balance{currency: currency, amount: balance}
  end

  defp to_symbol(base, quote) do
    "KUCOIN:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{base}:#{quote}"
  end

  def get_min_amount(base, _price) do
    case base do
      _ -> 1.0
    end
  end

  # Get precision at https://api.kucoin.com/v1/market/open/coins
  def get_amount_precision(base, _quote) do
    case base do
      "KCS" -> 4
      "KICK" -> 4
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

  defp parse_timestamp(string) do
    NaiveDateTime.from_iso8601!(string)
  end

  defp get_sign(%{"direction" => "BUY"}), do: 1
  defp get_sign(%{"direction" => "SELL"}), do: -1

  def get_link(base, quote) do
    "https://www.kucoin.com/#/trade.pro/#{base}-#{quote}"
  end
end
