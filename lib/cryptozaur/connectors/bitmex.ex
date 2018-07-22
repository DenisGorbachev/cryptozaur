defmodule Cryptozaur.Connectors.Bitmex do
  import Logger
  import OK, only: [success: 1, failure: 1]

  import Cryptozaur.Utils
  alias Cryptozaur.Model.{Trade, Level}
  alias Cryptozaur.Drivers.BitmexRest, as: Rest
  alias Cryptozaur.Drivers.BitmexWebsocket, as: Websocket

  # one month
  @iterate_trades_period 60 * 60 * 24 * 28
  @max_count 500

  def get_latest_trades(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      trades <- Rest.get_trades(rest, base, quote)
      symbol = to_symbol(base, quote)
      result = Enum.map(trades, &to_trade(symbol, &1))
    after
      result
    end
  end

  def get_trades(base, quote, from, to, extra \\ %{}) do
    OK.for do
      extra = Map.merge(extra, %{startTime: from, endTime: to})
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      trades <- Rest.get_trades(rest, base, quote, extra)
      symbol = to_symbol(base, quote)
      result = Enum.map(trades, &to_trade(symbol, &1))
    after
      result
    end
  end

  def iterate_trades(base, quote, from, to, {module, function, arguments} = callback) do
    # TODO: determine max count
    debug(">> Bitmex.iterate_trades(#{inspect(base)}, #{inspect(quote)}, #{inspect(from)}, #{inspect(to)}, callback)")
    actual_from = max_date(from, NaiveDateTime.add(to, -@iterate_trades_period))

    success(trades) = get_trades(base, quote, actual_from, to, %{count: @max_count})
    apply(module, function, arguments ++ [trades])

    debug("~~ Bitmex.iterate_trades(#{inspect(base)}, #{inspect(quote)}, #{inspect(from)}, #{inspect(to)}, callback) # fetched #{length(trades)} trades")

    if fetch_more?(trades) do
      last_timestamp = List.last(trades).timestamp
      iterate_trades(base, quote, from, last_timestamp, callback)
    end
  end

  def fetch_more?(trades) do
    # Don't check if length(trades) < limit: Bitmex might change the limit
    length(trades) != 0 and List.first(trades).timestamp != List.last(trades).timestamp
  end

  def place_order(key, secret, base, quote, amount, price, extra) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      result <- Rest.place_order(rest, base, quote, amount, price, extra)
    after
      case result do
        %{"ordStatus" => "Canceled", "text" => reason} -> failure(reason)
        %{"orderID" => uid} -> success(uid)
      end
    end
  end

  def change_order(key, secret, _base, _quote, uid, amount, price, extra) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"orderID" => uid} <- Rest.change_order(rest, uid, %{amount: amount, price: price}, extra)
    after
      uid
    end
  end

  def cancel_order(key, secret, _base, _quote, uid) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      [%{"orderID" => uid}] <- Rest.delete_order(rest, uid)
    after
      uid
    end
  end

  def subscribe_trades(base, quote) do
    Task.start_link(__MODULE__, :track_trades, [base, quote, self()])
  end

  def track_trades(base, quote, process) do
    with {:ok, websocket} <- Cryptozaur.DriverSupervisor.get_public_driver(Websocket),
         {:ok, _} <- Websocket.subscribe_trades(websocket, base, quote) do
      symbol = to_symbol(base, quote)
      receive_trade_dump(symbol, process)
      receive_next_trades(symbol, process)
    else
      {:error, error} -> raise error
    end
  end

  defp receive_trade_dump(symbol, process) do
    receive do
      {_event, %{initial: true, insert: entries}} ->
        trades = Enum.map(entries, &to_trade(symbol, &1))
        send(process, {__MODULE__, trades})
    end
  end

  defp receive_next_trades(symbol, process) do
    receive do
      {_event, %{insert: entries}} ->
        trades = Enum.map(entries, &to_trade(symbol, &1))
        send(process, {__MODULE__, trades})
    end

    receive_next_trades(symbol, process)
  end

  def subscribe_positions(base, quote, key, secret) do
    OK.for do
      me = self()
      websocket <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Websocket)
    after
      Task.start_link(fn ->
        OK.try do
          _ <- Websocket.subscribe_positions(websocket, base, quote)
        after
          track_positions(me)
        rescue
          error -> raise error
        end
      end)
    end
  end

  def subscribe_orders(base, quote, key, secret) do
    OK.for do
      me = self()
      websocket <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Websocket)
    after
      Task.start_link(fn ->
        OK.try do
          _ <- Websocket.subscribe_orders(websocket, base, quote)
        after
          track_orders(me)
        rescue
          error -> raise error
        end
      end)
    end
  end

  def subscribe_levels(base, quote) do
    OK.for do
      me = self()
      websocket <- Cryptozaur.DriverSupervisor.get_public_driver(Websocket)
    after
      Task.start_link(fn ->
        OK.try do
          _ <- Websocket.subscribe_orderbook(websocket, base, quote)
        after
          track_levels(me)
        rescue
          error -> raise error
        end
      end)
    end
  end

  defp track_positions(process) do
    track_initial_positions_message(process)
    |> track_positions_changes(process)
  end

  defp track_initial_positions_message(process) do
    _storage =
      receive do
        {_event, %{initial: true} = changes} ->
          storage =
            Map.delete(changes, :initial)
            |> Enum.reduce([], &update_position_storage/2)

          send(process, {__MODULE__, storage})
          storage

        _ ->
          track_initial_positions_message(process)
      end
  end

  defp track_positions_changes(storage, process) do
    update_storage =
      receive do
        {_event, changes} -> Enum.reduce(changes, storage, &update_position_storage/2)
      end

    send(process, {__MODULE__, update_storage})

    track_positions_changes(update_storage, process)
  end

  defp update_position_storage({action, changes}, storage) do
    Enum.reduce(changes, storage, &update_position_storage_entry(action, &1, &2))
  end

  defp update_position_storage_entry(
         :insert,
         %{
           "currentQty" => amount
         },
         storage
       ) do
    [%{amount: amount} | storage]
  end

  defp update_position_storage_entry(
         :update,
         %{
           "currentQty" => amount
         },
         storage
       ) do
    # currently only one position is expected so update it
    [Map.put(List.first(storage), :amount, amount)]
  end

  # useless update (like ping)
  defp update_position_storage_entry(:update, _, storage), do: storage

  defp track_orders(process) do
    track_initial_orders_message(process)
    |> track_orders_changes(process)
  end

  defp track_initial_orders_message(process) do
    _storage =
      receive do
        {_event, %{initial: true} = changes} ->
          storage =
            Map.delete(changes, :initial)
            |> Enum.reduce(%{}, &update_orders_storage/2)

          send(process, {__MODULE__, Map.values(storage)})
          storage

        _ ->
          track_initial_orders_message(process)
      end
  end

  defp track_orders_changes(storage, process) do
    update_storage =
      receive do
        {_event, changes} -> Enum.reduce(changes, storage, &update_orders_storage/2)
      end

    send(process, {__MODULE__, Map.values(update_storage)})

    track_orders_changes(update_storage, process)
  end

  defp update_orders_storage({action, changes}, storage) do
    Enum.reduce(changes, storage, &update_orders_storage_entry(action, &1, &2))
  end

  defp update_orders_storage_entry(
         :insert,
         %{
           "side" => side,
           "orderID" => uid,
           "price" => price,
           "orderQty" => amount,
           "leavesQty" => leave,
           "ordType" => type,
           "timestamp" => timestamp_string
         },
         storage
       ) do
    timestamp = parse_timestamp(timestamp_string)

    sign =
      case side do
        "Buy" -> 1
        "Sell" -> -1
        _ -> raise "Unknown order side #{side}"
      end

    Map.put(storage, uid, %{
      uid: uid,
      # to float, nil for MARKET order
      price: if(price, do: Float.round(price / 1, 1)),
      amount_requested: amount * sign,
      amount_filled: amount - leave,
      status: "active",
      type: type,
      timestamp: timestamp
    })
  end

  defp update_orders_storage_entry(:update, %{"orderID" => uid, "ordStatus" => status}, storage) when status == "Filled" or status == "Canceled" do
    Map.delete(storage, uid)
  end

  defp update_orders_storage_entry(:update, %{"orderID" => uid} = change, storage) do
    updated_order =
      Map.get(storage, uid)
      |> update_order_price(change)
      |> update_order_amount(change)

    Map.put(storage, uid, updated_order)
  end

  defp update_order_price(order, change) do
    if Map.has_key?(change, "price") do
      Map.put(order, :price, change["price"] / 1)
    else
      order
    end
  end

  defp update_order_amount(order, change) do
    if Map.has_key?(change, "orderQty") do
      Map.put(order, :amount, change["orderQty"])
    else
      order
    end
  end

  defp track_levels(process) do
    track_initial_levels_message(process)
    |> track_levels_changes(process)
  end

  defp track_initial_levels_message(process) do
    _storage =
      receive do
        {_event, %{initial: true} = changes} ->
          storage =
            Map.delete(changes, :initial)
            |> Enum.reduce(%{"Buy" => %{}, "Sell" => %{}}, &update_levels_storage/2)

          result = to_result(storage)
          send(process, {__MODULE__, result})
          storage

        _ ->
          track_initial_levels_message(process)
      end
  end

  defp track_levels_changes(storage, process) do
    update_storage =
      try do
        receive do
          {_event, changes} -> Enum.reduce(changes, storage, &update_levels_storage/2)
        end
      rescue
        _error -> storage
      end

    result = to_result(update_storage)
    send(process, {__MODULE__, result})

    track_levels_changes(update_storage, process)
  end

  defp update_levels_storage({action, changes}, storage) do
    Enum.reduce(changes, storage, &update_levels_storage_entry(action, &1, &2))
  end

  defp update_levels_storage_entry(:insert, %{"id" => id, "price" => price, "side" => side, "size" => amount}, storage) do
    %{storage | side => Map.put(storage[side], id, %Level{price: price / 1, amount: amount})}
  end

  defp update_levels_storage_entry(:update, %{"id" => id, "side" => side, "size" => amount}, storage) do
    put_in(storage[side][id].amount, amount)
  end

  defp update_levels_storage_entry(:delete, %{"id" => id, "side" => side}, storage) do
    %{storage | side => Map.delete(storage[side], id)}
  end

  defp to_result(storage) do
    %{
      buys: storage["Buy"] |> Map.values() |> Enum.sort_by(&Map.get(&1, :price), &>=/2),
      sells: storage["Sell"] |> Map.values() |> Enum.sort_by(&Map.get(&1, :price), &<=/2)
    }
  end

  defp to_trade(symbol, %{"trdMatchID" => id, "homeNotional" => amount, "price" => price, "side" => type, "timestamp" => timestamp_string}) do
    sign =
      case type do
        "Buy" -> 1
        "Sell" -> -1
      end

    amount = to_float(amount)
    price = to_float(price)
    timestamp = parse_timestamp(timestamp_string)

    %Trade{uid: id, symbol: symbol, timestamp: timestamp, amount: amount * sign, price: price}
  end

  def get_min_amount(_base, _price) do
    # BitMEX always trades full contracts (you can't buy 0.5 ETH contracts, only 1 ETH contract)
    1.0
  end

  def get_amount_precision(_base, _quote) do
    # BitMEX always trades full contracts (you can't buy 0.5 ETH contracts, only 1 ETH contract)
    0
  end

  def get_price_precision(base, quote) do
    case base do
      "XBT" -> 1
      "BCH" -> 4
      "ETH" -> 5
      "LTC" -> 5
      "ADA" -> 8
      "XRP" -> 8
      _ -> raise "Find out price precision for BITMEX:#{base}:#{quote}"
    end
  end

  def get_tick(base, quote) do
    case base do
      "XBT" -> 0.5
      "BCH" -> 0.0001
      "ETH" -> 0.00001
      "LTC" -> 0.00001
      "ADA" -> 0.00000001
      "XRP" -> 0.00000001
      _ -> raise "Find out tick size for BITMEX:#{base}:#{quote}"
    end
  end

  def get_link(base, quote) do
    case quote do
      # Use month codes from https://www.bitmex.com/app/futuresGuideExamples#Futures-Month-Codes
      "BTC" ->
        "https://www.bitmex.com/app/trade/#{base}M18"

      "USD" ->
        "https://www.bitmex.com/app/trade/#{base}#{quote}"
    end
  end

#  defp to_pair(base, quote) do
#    "#{base}#{quote}"
#  end

  defp to_symbol(base, quote) do
    "BITMEX:#{base}:#{quote}"
  end

  defp parse_timestamp(string) do
    NaiveDateTime.from_iso8601!(string)
  end
end
