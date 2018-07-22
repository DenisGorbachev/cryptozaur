defmodule Cryptozaur.Drivers.KucoinRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 90000
  @first_fetch_page 1
  @max_balance_per_page 20

  def start_link(state, opts \\ []) do
    state = Map.put(state, :nonce, :os.system_time(:milli_seconds))
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_tickers(pid) do
    GenServer.call(pid, {:get_tickers}, @timeout)
  end

  def get_balance(pid, currency) do
    GenServer.call(pid, {:get_balance, currency}, @timeout)
  end

  def get_balances(pid) do
    GenServer.call(pid, {:get_balances}, @timeout)
  end

  def create_order(pid, symbol, amount, price, type) do
    GenServer.call(pid, {:create_order, symbol, amount, price, type}, @timeout)
  end

  def cancel_order(pid, symbol, orderOid, type) do
    GenServer.call(pid, {:cancel_order, symbol, orderOid, type}, @timeout)
  end

  def get_open_orders(pid) do
    GenServer.call(pid, {:get_open_orders}, @timeout)
  end

  def get_closed_orders(pid) do
    GenServer.call(pid, {:get_closed_orders}, @timeout)
  end

  # Server

  def handle_call({:get_tickers}, _from, state) do
    path = "/v1/market/open/symbols"
    params = %{}
    result = get(path, params, [], [is_signed: false], state)
    {:reply, result, state}
  end

  def handle_call({:create_order, symbol, amount, price, type}, _from, state) do
    path = "/v1/order"
    params = %{symbol: symbol, amount: amount, price: price, type: type}
    body = []
    result = post(path, body, params, [], [is_signed: true], state)
    {:reply, result, state}
  end

  # NOTE: Kucoin reports success even if the order doesn't exist or is already cancelled
  def handle_call({:cancel_order, symbol, orderOid, type}, _from, state) do
    path = "/v1/cancel-order"
    params = %{orderOid: orderOid, symbol: symbol, type: type}
    body = []
    result = post(path, body, params, [], [is_signed: true], state)
    {:reply, result, state}
  end

  def handle_call({:get_open_orders}, _from, state) do
    path = "/v1/order/active-map"
    params = %{}
    result = get(path, params, [], [is_signed: true], state)
    {:reply, result, state}
  end

  def handle_call({:get_closed_orders}, _from, state) do
    path = "/v1/order/dealt"
    params = %{limit: @max_balance_per_page, page: @first_fetch_page}
    result = recursive_pagination_call(path, params, [], [is_signed: true], state)
    {:reply, result, state}
  end

  def handle_call({:get_balance, currency}, _from, state) do
    path = "/v1/account/#{currency}/balance"
    params = %{}
    result = get(path, params, [], [is_signed: true], state)
    {:reply, result, state}
  end

  def handle_call({:get_balances}, _from, state) do
    path = "/v1/account/balances"
    params = %{limit: @max_balance_per_page, page: @first_fetch_page}
    result = recursive_pagination_call(path, params, [], [is_signed: true], state)
    {:reply, result, state}
  end

  def handle_call({:get_trades, _symbol, _limit, _since}, _from, state) do
    path = "/v1/account/balances"
    params = %{limit: @max_balance_per_page, page: @first_fetch_page}
    result = recursive_pagination_call(path, params, [], [is_signed: false], state)
    {:reply, result, state}
  end

  defp recursive_pagination_call(path, params, headers, options, state) do
    with success(response) <- get(path, params, headers, options, state) do
      datasLength = length(response["datas"])

      if datasLength < @max_balance_per_page do
        success(response)
      else
        params = %{params | page: params.page + 1}
        with success(response_next) <- recursive_pagination_call(path, params, headers, options, state) do
          success(response |> Map.update("datas", response["datas"], &(response_next["datas"] ++ &1)))
        end
      end
    end
  end

  defp get(path, params, headers, options, state) do
    request(:get, path, [], params, headers, options, state)
  end

  defp post(path, body, params, headers, options, state) do
    request(:post, path, body, params, headers, options, state)
  end

  defp request(method, path, body, params, headers, options, state) do
    GenRetry.Task.async(request_task(method, path, body, params, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout], state), retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body, params, headers, options, state) do
    url = "https://api.kucoin.com" <> path

    fn ->
      # Add Kucoin-specific header
      headers = [{:"Accept-Language", "zh_CN"} | headers]
      headers = if Keyword.get(options, :is_signed, false), do: headers |> Keyword.merge(signature_headers(path, body, params, state)), else: headers
      body = if is_list(body) or is_map(body), do: Poison.encode!(body), else: body
      case HTTPoison.request(method, url, body, headers, options ++ [params: params]) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ KucoinRest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          case parse!(response.body) do
            # Kucoin is throttling requests to their API backend, which results in stale nonce sometimes
            # I know, this is utterly insane
            %{"code" => "UNAUTH", "success" => false, "msg" => "Invalid nonce"} -> raise "retry"
            result -> result
          end
      end
    end
  end

  defp signature_headers(path, _body, params, state) do
    # Elixir automatically arranges map keys in alphabetic order
    query = params |> URI.encode_query()
    nonce = :os.system_time(:milli_seconds)
    sign = path <> "/" <> Integer.to_string(nonce) <> "/" <> query
    signature = :crypto.hmac(:sha256, state.secret, Base.encode64(sign)) |> Base.encode16() |> String.downcase()
    ["KC-API-KEY": state.key, "KC-API-NONCE": nonce, "KC-API-SIGNATURE": signature]
  end

  defp validate(response) do
    case response do
      %{"success" => true, "data" => data} -> success(data)
      %{"success" => false, "msg" => msg} -> failure(msg)
    end
  end
end
