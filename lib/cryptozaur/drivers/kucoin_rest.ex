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
    result = get(path, params)
    {:reply, result, state}
  end

  def handle_call({:create_order, symbol, amount, price, type}, _from, state) do
    path = "/v1/order"
    params = %{symbol: symbol, amount: amount, price: price, type: type}
    body = ""
    {nonce, state} = increment_nonce(state)
    result = post(path, body, params, signature_headers(path, params, nonce, state))
    {:reply, result, state}
  end

  # NOTE: Kucoin reports success even if the order doesn't exist or is already cancelled
  def handle_call({:cancel_order, symbol, orderOid, type}, _from, state) do
    path = "/v1/cancel-order"
    params = %{orderOid: orderOid, symbol: symbol, type: type}
    body = ""
    {nonce, state} = increment_nonce(state)
    result = post(path, body, params, signature_headers(path, params, nonce, state))
    {:reply, result, state}
  end

  def handle_call({:get_open_orders}, _from, state) do
    path = "/v1/order/active-map"
    params = %{}
    _body = ""
    {nonce, state} = increment_nonce(state)
    result = get(path, params, signature_headers(path, params, nonce, state))
    {:reply, result, state}
  end

  def handle_call({:get_closed_orders}, _from, state) do
    path = "/v1/order/dealt"
    parameters = %{limit: @max_balance_per_page, page: @first_fetch_page}
    result = success(recursive_pagination_call({path, parameters}, state))
    {:reply, result, state}
  end

  def handle_call({:get_balance, currency}, _from, state) do
    path = "/v1/account/#{currency}/balance"
    params = %{}
    {nonce, state} = increment_nonce(state)
    result = get(path, params, signature_headers(path, params, nonce, state))
    {:reply, result, state}
  end

  def handle_call({:get_balances}, _from, state) do
    path = "/v1/account/balances"
    parameters = %{limit: @max_balance_per_page, page: @first_fetch_page}
    %{"datas" => result} = recursive_pagination_call({path, parameters}, state)
    {:reply, success(result), state}
  end

  def handle_call({:get_trades, _symbol, _limit, _since}, _from, state) do
    path = "/v1/account/balances"
    parameters = %{limit: @max_balance_per_page, page: @first_fetch_page}
    result = success(recursive_pagination_call({path, parameters}, state))
    {:reply, result, state}
  end

  defp recursive_pagination_call({path, params}, state) do
    {nonce, state} = increment_nonce(state)
    result = get(path, params, signature_headers(path, params, nonce, state))
    success(response) = result
    params = %{params | page: params.page + 1}
    datasLength = length(response["datas"])

    if datasLength < @max_balance_per_page do
      response
    else
      resultRecursive = recursive_pagination_call({path, params}, state)
      Map.update(response, "datas", resultRecursive["datas"], &List.flatten([resultRecursive["datas"] | &1]))
    end
  end

  defp get(path, params \\ [], headers \\ [], options \\ []) do
    request(:get, path, "", headers, options ++ [params: params])
  end

  defp post(path, body \\ "", params \\ [], headers \\ [], options \\ []) do
    request(:post, path, body, headers, options ++ [params: params])
  end

  defp request(method, path, body \\ "", headers \\ [], options \\ []) do
    GenRetry.Task.async(request_task(method, path, body, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout]), retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body \\ "", headers \\ [], options \\ []) do
    url = "https://api.kucoin.com" <> path

    fn ->
      case HTTPoison.request(method, url, body, headers, options) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ KucoinRest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          parse!(response.body)
      end
    end
  end

  defp signature_headers(path, params, nonce, state) do
    # Elixir automatically arranges map keys in alphabetic order
    query = params |> URI.encode_query()
    sign = path <> "/#{nonce}/" <> query
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
