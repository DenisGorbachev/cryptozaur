defmodule Cryptozaur.Drivers.BinanceRest do
  # https://github.com/binance-exchange/binance-official-api-docs/blob/master/rest-api.md
  use HTTPoison.Base
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @url "https://www.binance.com/api/"
  @timeout 600_000
  @http_timeout 30000
  @recv_window 5000

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  # Client
  def get_aggregated_trades(pid, base, quote, opts \\ %{}) do
    GenServer.call(pid, {:get_aggregated_trades, base, quote, opts}, @timeout)
  end

  def get_orderbook(pid, base, quote, opts \\ %{}) do
    GenServer.call(pid, {:get_orderbook, base, quote, opts}, @timeout)
  end

  def get_account(pid) do
    GenServer.call(pid, {:account}, @timeout)
  end

  def get_all_orders(pid, base, quote) do
    GenServer.call(pid, {:all_orders, base, quote}, @timeout)
  end

  def get_my_trades(pid, base, quote) do
    GenServer.call(pid, {:my_trades, base, quote}, @timeout)
  end

  def get_levels(pid, base, quote, depth) do
    GenServer.call(pid, {:levels, base, quote, depth}, @timeout)
  end

  # TODO: refactor the code below
  def get_open_orders(pid, symbol \\ nil) do
    GenServer.call(pid, {:open_orders, symbol}, @timeout)
  end

  def cancel_order(pid, symbol, order_id \\ nil, orig_client_order_id \\ nil, new_client_order_id \\ nil) do
    GenServer.call(pid, {:cancel, symbol, order_id, orig_client_order_id, new_client_order_id}, @timeout)
  end

  def place_order(pid, symbol, side, type, quantity, opts \\ %{}, test \\ false) do
    GenServer.call(pid, {:order, symbol, side, type, quantity, opts, test}, @timeout)
  end

  def place_limit_order(pid, symbol, side, quantity, price, time_in_force \\ "GTC", test \\ false) do
    opts = %{"timeInForce" => time_in_force, "price" => price}
    place_order(pid, symbol, side, "LIMIT", quantity, opts, test)
  end

  def place_market_order(pid, symbol, side, quantity, test \\ false) do
    place_order(pid, symbol, side, "MARKET", quantity, %{}, test)
  end

  def place_stop_loss_order(pid, symbol, side, quantity, stop_price, test \\ false) do
    opts = %{"stopPrice" => stop_price}
    place_order(pid, symbol, side, "STOP_LOSS", quantity, opts, test)
  end

  def place_stop_loss_limit_order(pid, symbol, side, quantity, stop_price, price, time_in_force, test \\ false) do
    opts = %{"stopPrice" => stop_price, "timeInForce" => time_in_force, "price" => price}
    place_order(pid, symbol, side, "STOP_LOSS_LIMIT", quantity, opts, test)
  end

  def place_take_profit_order(pid, symbol, side, quantity, stop_price, test \\ false) do
    opts = %{"stopPrice" => stop_price}
    place_order(pid, symbol, side, "TAKE_PROFIT", quantity, opts, test)
  end

  def place_take_profit_limit_order(pid, symbol, side, quantity, stop_price, price, time_in_force, test \\ false) do
    opts = %{"stopPrice" => stop_price, "timeInForce" => time_in_force, "price" => price}
    place_order(pid, symbol, side, "TAKE_PROFIT_LIMIT", quantity, opts, test)
  end

  def place_limit_maker_order(pid, symbol, side, quantity, price, test \\ false) do
    opts = %{"price" => price}
    place_order(pid, symbol, side, "LIMIT_MAKER", quantity, opts, test)
  end

  def get_tickers(pid, symbol \\ nil) do
    GenServer.call(pid, {:tickers, symbol}, @timeout)
  end

  @torches_limit 500
  def get_torches_limit(), do: @torches_limit

  def get_torches(pid, base, quote, from, to, resolution, limit \\ @torches_limit) do
    GenServer.call(pid, {:torches, base, quote, from, to, resolution, limit}, @timeout)
  end

  # Server
  def handle_call({:account}, _from, state) do
    url = "https://www.binance.com/api/v3/account"
    parameters = %{}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:cancel, symbol, order_id, orig_client_order_id, new_client_order_id}, _from, state) do
    url = "https://www.binance.com/api/v3/order"
    parameters = %{"symbol" => symbol}

    parameters =
      case order_id do
        nil -> parameters
        _ -> Map.put(parameters, "orderId", order_id)
      end

    parameters =
      case orig_client_order_id do
        nil -> parameters
        _ -> Map.put(parameters, "origClientOrderId", orig_client_order_id)
      end

    parameters =
      case new_client_order_id do
        nil -> parameters
        _ -> Map.put(parameters, "newClientOrderId", new_client_order_id)
      end

    result = send_private_request(url, parameters, state, :delete)

    {:reply, result, state}
  end

  def handle_call({:open_orders, symbol}, _from, state) do
    url = "https://www.binance.com/api/v3/openOrders"

    parameters =
      case symbol do
        nil -> %{}
        _ -> %{"symbol" => symbol}
      end

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:order, symbol, side, type, quantity, opts, test}, _from, state) do
    url =
      case test do
        true -> "https://www.binance.com/api/v3/order/test"
        false -> "https://www.binance.com/api/v3/order"
      end

    parameters =
      opts
      |> Map.put("symbol", symbol)
      |> Map.put("side", side)
      |> Map.put("type", type)
      # Binance
      |> Map.put("quantity", format_float(quantity, 8))
      |> Map.put("price", format_float(opts["price"], 8))
      |> Map.put("newOrderRespType", "FULL")

    result = send_private_request(url, parameters, state, :post)

    {:reply, result, state}
  end

  def handle_call({:get_aggregated_trades, base, quote, opts}, _from, state) do
    parameters = Map.put(opts, :symbol, to_binance_symbol(base, quote))
    parameters = if Map.get(opts, :startTime), do: Map.put(parameters, :startTime, to_binance_timestamp(opts[:startTime])), else: parameters
    parameters = if Map.get(opts, :endTime), do: Map.put(parameters, :endTime, to_binance_timestamp(opts[:endTime])), else: parameters
    result = send_public_request("https://www.binance.com/api/v1/aggTrades", parameters)
    {:reply, result, state}
  end

  def handle_call({:get_orderbook, base, quote, opts}, _from, state) do
    parameters = Map.put(opts, :symbol, to_binance_symbol(base, quote))
    result = send_public_request("https://www.binance.com/api/v1/depth", parameters)
    {:reply, result, state}
  end

  def handle_call({:tickers, symbol}, _from, state) do
    url = "https://www.binance.com/api/v1/ticker/24hr"
    parameters = %{}
    parameters = if symbol, do: %{parameters | "symbol" => symbol}, else: parameters

    result = send_public_request(url, parameters)

    {:reply, result, state}
  end

  def handle_call({:torches, base, quote, from, to, resolution, _limit}, _from, state) do
    url = "https://www.binance.com/api/v1/klines"
    parameters = %{"symbol" => to_binance_symbol(base, quote), "interval" => to_binance_resolution(resolution), "startTime" => to_binance_timestamp(from), "endTime" => to_binance_timestamp(to)}

    result = send_public_request(url, parameters)

    {:reply, result, state}
  end

  def handle_call({:all_orders, base, quote}, _from, state) do
    url = "https://www.binance.com/api/v3/allOrders"
    parameters = %{"symbol" => to_binance_symbol(base, quote)}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:my_trades, base, quote}, _from, state) do
    url = "https://www.binance.com/api/v3/myTrades"
    parameters = %{"symbol" => to_binance_symbol(base, quote)}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:levels, base, quote, depth}, _from, state) do
    depth = if depth == 0, do: 1000, else: depth
    url = "https://www.binance.com/api/v1/depth"
    parameters = %{"symbol" => to_binance_symbol(base, quote), "limit" => depth}

    result = send_public_request(url, parameters)

    {:reply, result, state}
  end

  defp send_public_request(path, parameters) do
    body = URI.encode_query(parameters)

    task =
      GenRetry.Task.async(
        fn ->
          case get(path <> "?" <> body, [], timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Binance.Rest.send_public_request(#{inspect(path)}, #{inspect(parameters)}) # timeout")
              raise "retry"

            failure(error) ->
              failure(error)

            success(response) ->
              parse!(response.body)

              # Retry on exception (#rationale: sometimes Bittrex returns "The service is unavailable" instead of proper JSON)
          end
        end,
        retries: 10,
        delay: 2_000,
        jitter: 0.1,
        exp_base: 1.1
      )

    payload = Task.await(task, @timeout)
    validate(payload)
  end

  defp send_private_request(url, parameters, %{key: key, secret: secret}, method \\ :get) do
    timestamp = :os.system_time(:milli_seconds)

    full_parameters =
      parameters
      |> Map.put("timestamp", timestamp)
      |> Map.put("recvWindow", @recv_window)
      |> URI.encode_query()

    signature =
      :crypto.hmac(:sha256, secret, full_parameters)
      |> Base.encode16()
      |> String.downcase()

    uri = url <> "?" <> full_parameters <> "&signature=" <> signature
    headers = ["X-MBX-APIKEY": key]

    task =
      GenRetry.Task.async(
        fn ->
          case request(method, uri, "", headers, timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Binance.Rest.send_private_request(#{inspect(url)}, #{inspect(parameters)}) # timeout")
              raise "retry"

            failure(error) ->
              failure(error)

            success(response) ->
              parse!(response.body)

              # Retry on exception (#rationale: sometimes Bittrex returns "The service is unavailable" instead of proper JSON)
          end
        end,
        retries: 10,
        delay: 2_000,
        jitter: 0.1,
        exp_base: 1.1
      )

    payload = Task.await(task, @timeout)
    validate(payload)
  end

  def validate(response) do
    case response do
      %{"code" => _, "msg" => result} -> failure(result)
      _ -> success(response)
    end
  end

  defp to_binance_symbol(base, quote), do: base <> quote

  @intervals ["1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M"]
  defp to_binance_resolution(resolution) do
    interval =
      cond do
        resolution < 60 * 60 -> "#{to_integer(resolution / 60)}m"
        resolution < 24 * 60 * 60 -> "#{to_integer(resolution / 60 / 60)}h"
        resolution < 7 * 24 * 60 * 60 -> "#{to_integer(resolution / 24 / 60 / 60)}d"
        resolution < 31 * 24 * 60 * 60 -> "#{to_integer(resolution / 7 / 24 / 60 / 60)}w"
        resolution < 365 * 24 * 60 * 60 -> "#{to_integer(resolution / 31 / 24 / 60 / 60)}M"
      end

    if not (interval in @intervals), do: raise("[Binance] Unsupported resolution #{resolution} (translated as #{interval})")
    interval
  end

  defp to_binance_timestamp(timestamp) do
    to_unix(timestamp) * 1000
  end
end
