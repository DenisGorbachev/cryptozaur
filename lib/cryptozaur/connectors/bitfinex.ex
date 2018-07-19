defmodule Cryptozaur.Connectors.Bitfinex do
  import Cryptozaur.Logger
  import OK, only: [success: 1, failure: 1]
  import Cryptozaur.Utils
  alias Cryptozaur.Model.{Trade, Level, Balance, Candle, Ticker}
  alias Cryptozaur.Drivers.BitfinexRest, as: Rest
  alias Cryptozaur.Drivers.BitfinexWebsocket, as: Websocket

  @max_trade_limit 1000

  def subscribe_ticker(base, quote) do
    Task.start_link(__MODULE__, :track_ticker, [base, quote, self()])
  end

  def track_ticker(base, quote, process) do
    with {:ok, websocket} <- Cryptozaur.DriverSupervisor.get_public_driver(Websocket),
         {:ok, _} <- Websocket.subscribe_ticker(websocket, base, quote) do
      symbol = to_symbol(base, quote)
      receive_ticker_update(symbol, process)
    else
      {:error, error} -> raise error
    end
  end

  defp receive_ticker_update(symbol, process) do
    receive do
      {_event, entry} ->
        ticker = to_ticker(symbol, entry)
        send(process, {__MODULE__, ticker})
    end

    receive_ticker_update(symbol, process)
  end

  def subscribe_trades(base, quote) do
    Task.start_link(__MODULE__, :track_trades, [base, quote, self()])
  end

  def track_trades(base, quote, process) do
    with {:ok, websocket} <- Cryptozaur.DriverSupervisor.get_public_driver(Websocket),
         {:ok, _} <- Websocket.subscribe_trades(websocket, base, quote) do
      symbol = to_symbol(base, quote)
      receive_trade_dump(symbol, process)
      receive_next_trade(symbol, process)
    else
      {:error, error} -> raise error
    end
  end

  defp receive_trade_dump(symbol, process) do
    receive do
      {_event, entries} ->
        trades = Enum.map(entries, &to_trade(symbol, &1))
        send(process, {__MODULE__, trades})
    end
  end

  defp receive_next_trade(symbol, process) do
    receive do
      {_event, entry} ->
        trade = to_trade(symbol, entry)
        send(process, {__MODULE__, [trade]})
    end

    receive_next_trade(symbol, process)
  end

  def iterate_trades(base, quote, from, to, callback) do
    debug_enter(%{base: base, quote: quote, from: from, to: to})

    result =
      with {:ok, rest} <- Cryptozaur.DriverSupervisor.get_public_driver(Rest) do
        symbol = to_symbol(base, quote)
        do_iterate_trades(rest, symbol, base, quote, from, to, callback)
      end

    debug_return(result)
  end

  defp do_iterate_trades(rest, symbol, base, quote, from, to, {module, function, arguments} = callback) do
    with {:ok, entries} <- Rest.get_trades(rest, base, quote, %{limit: @max_trade_limit, start: to_millis(from), end: to_millis(to)}) do
      trades = Enum.map(entries, &to_trade(symbol, &1))
      apply(module, function, arguments ++ [trades])

      debug_step(%{to: to, trades: length(trades)})

      if fetch_more?(trades) do
        last_timestamp = List.last(trades).timestamp

        # beware of undeterministic rate limit
        # Bitfinex punishes for it!
        Process.sleep(4000)

        do_iterate_trades(rest, symbol, base, quote, from, last_timestamp, callback)
      end
    end
  end

  def fetch_more?(trades) do
    length(trades) != 0 and List.first(trades).timestamp != List.last(trades).timestamp
  end

  def credentials_valid?(key, secret) do
    with success(rest) <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest) do
      case Rest.get_balances(rest) do
        success(_) -> success(true)
        failure("10100: apikey: invalid") -> success(false)
        failure(message) -> failure(message)
      end
    end
  end

  def pair_valid?(base, quote) do
    OK.try do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      _ticker <- Rest.get_ticker(rest, base, quote)
    after
      success(true)
    rescue
      "10020: symbol: invalid" -> success(false)
      error -> failure(error)
    end
  end

  def get_candles(base, quote, resolution) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      candles <- Rest.get_candles(rest, base, quote, resolution)
      symbol = to_symbol(base, quote)
      result = Enum.map(candles, &to_candle(&1, symbol, resolution))
    after
      result
    end
  end

  def get_ticker(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      data <- Rest.get_ticker(rest, base, quote)
    after
      symbol = to_symbol(base, quote)
      to_ticker(symbol, data)
    end
  end

  def get_tickers() do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      tickers <- Rest.get_tickers(rest)
      result = Enum.map(tickers, &to_ticker/1)
    after
      result
    end
  end

  def get_latest_trades(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      trades <- Rest.get_trades(rest, base, quote, %{limit: @max_trade_limit})
      symbol = to_symbol(base, quote)
      result = Enum.map(trades, &to_trade(symbol, &1))
    after
      result
    end
  end

  def get_levels(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      levels <- Rest.get_order_book(rest, base, quote)
      symbol = to_symbol(base, quote)

      structs = Enum.map(levels, &to_level(symbol, &1))

      buys = Enum.filter(structs, &(&1.amount > 0))
      sells = Enum.filter(structs, &(&1.amount < 0))
    after
      {buys, sells}
    end
  end

  def get_balances(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      balances <- Rest.get_balances(rest)
      result = Enum.map(balances, &to_balance(&1))
    after
      result
    end
  end

  def get_price_precision(base, quote) do
    case quote do
      "USD" ->
        case base do
          "BTC" -> 2
          "IOT" -> 5
          _ -> 4
        end

      _ ->
        8
    end
  end

  def get_amount_precision(base, _quote) do
    # TODO: correct it
    case base do
      _ -> 8
    end
  end

  # TODO: fix this
  def get_tick(base, quote) do
    case quote do
      "USD" ->
        case base do
          "BTC" -> 0.1
          "ETH" -> 0.01
          _ -> raise "Find out tick size by visiting https://www.bitfinex.com/order_book/#{String.downcase("#{base}#{quote}")}"
        end

      _ ->
        raise "Find out tick size by visiting https://www.bitfinex.com/order_book/#{String.downcase("#{base}#{quote}")}"
    end
  end

  def get_link(base, quote) do
    "https://www.bitfinex.com/t/#{base}:#{quote}"
  end

  defp to_trade(symbol, [id, unix, amount, price]) do
    timestamp = parse_time(unix)

    float_amount = amount / 1
    float_price = price / 1

    %Trade{uid: Integer.to_string(id), symbol: symbol, timestamp: timestamp, amount: float_amount, price: float_price}
  end

  defp to_level(symbol, [price, _count, amount]) do
    float_amount = amount / 1
    float_price = price / 1

    %Level{price: float_price, amount: float_amount, symbol: symbol}
  end

  # type: exchange, margin, funding
  defp to_balance([_type, currency, amount, _unsettled_interest, _balance_available]) do
    %Balance{currency: currency, amount: amount}
  end

  defp to_candle([unix, open, close, high, low, _volume], symbol, resolution) do
    timestamp = parse_time(unix)

    %Candle{
      symbol: symbol,
      open: open / 1,
      high: high / 1,
      low: low / 1,
      close: close / 1,
      timestamp: timestamp,
      resolution: resolution
    }
  end

  defp to_ticker(ticker) do
    bitfinex_symbol = List.first(ticker)
    [base, quote] = from_symbol(bitfinex_symbol)
    symbol = to_symbol(base, quote)
    to_ticker(symbol, List.delete_at(ticker, 0))
  end

  defp to_ticker(symbol, [bid, _, ask, _, _, _, _, volume, _, _]) do
    %Ticker{
      symbol: symbol,
      bid: to_float(bid),
      ask: to_float(ask),
      volume_24h_base: to_float(volume),
      # BITFINEX doesn't provide it
      volume_24h_quote: nil
    }
  end

  defp to_symbol(base, quote) do
    "BITFINEX:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{base}:#{quote}"
  end

  defp from_symbol(pair) do
    pair =
      pair
      |> String.slice(1..7)
      |> String.split_at(3)

    [elem(pair, 0), elem(pair, 1)]
  end

  defp parse_time(unix) do
    unix
    |> DateTime.from_unix!(:milliseconds)
    |> DateTime.to_naive()
  end

  defp to_millis(naive), do: naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:milliseconds)
end
