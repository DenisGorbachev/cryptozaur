defmodule Cryptozaur.Drivers.OkexRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 60000
  @base_url "https://www.okex.com"

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_ticker(pid, base, quote) do
    GenServer.call(pid, {:get_ticker, base, quote}, @timeout)
  end

  def get_tickers(pid) do
    GenServer.call(pid, {:get_tickers}, @timeout)
  end

  def get_userinfo(pid) do
    GenServer.call(pid, {:get_userinfo}, @timeout)
  end

  def trade(pid, symbol, type, amount, price) do
    GenServer.call(pid, {:trade, symbol, type, amount, price}, @timeout)
  end

  def cancel_order(pid, symbol, order_id) do
    GenServer.call(pid, {:cancel_order, symbol, order_id}, @timeout)
  end

  # Server

  def handle_call({:get_ticker, base, quote}, _from, state) do
    path = "/api/v1/ticker.do"
    params = %{symbol: to_symbol(base, quote)}
    result = get(path, params)
    {:reply, result, state}
  end

  def handle_call({:get_tickers}, _from, state) do
    path = "/v2/markets/tickers"
    result = get(path)
    {:reply, result, state}
  end

  def handle_call({:get_userinfo}, _from, state) do
    path = "/api/v1/userinfo.do"
    params = %{}
    body = params |> with_sign(state) |> URI.encode_query()
    result = post(path, body)
    {:reply, result, state}
  end

  def handle_call({:trade, symbol, type, amount, price}, _from, state) do
    path = "/api/v1/trade.do"
    params = %{"symbol" => symbol, "type" => type, "amount" => amount, "price" => price}
    body = params |> with_sign(state) |> URI.encode_query()
    result = post(path, body)
    {:reply, result, state}
  end

  def handle_call({:cancel_order, symbol, order_id}, _from, state) do
    path = "/api/v1/cancel_order.do"
    params = %{"symbol" => symbol, "order_id" => order_id}
    body = params |> with_sign(state) |> URI.encode_query()
    result = post(path, body)
    {:reply, result, state}
  end

  defp get(path, params \\ [], headers \\ [], options \\ []) do
    request(:get, path, "", headers, options ++ [params: params])
  end

  defp post(path, body, params \\ [], headers \\ [], options \\ []) do
    request(:post, path, body, headers ++ [{"Content-Type", "application/x-www-form-urlencoded"}], options ++ [params: params])
  end

  defp request(method, path, body, headers, options) do
    GenRetry.Task.async(fn -> request_task(method, path, body, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout]) end, retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body, headers, options) do
    url = @base_url <> path

    case HTTPoison.request(method, url, body, headers, options) do
      failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
        warn("~~ Okex.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
        raise "retry"

      failure(error) ->
        failure(error)

      success(response) ->
        parse!(response.body)
    end
  end

  defp to_symbol(base, quote) do
    "#{base}_#{quote}" |> String.downcase()
  end

  defp with_sign(params, state) do
    params |> Map.put("api_key", state.key) |> Map.put("sign", sign(params, state))
  end

  defp sign(params, state) do
    # Elixir automatically arranges map keys in alphabetic order
    query = params |> Map.merge(%{"api_key" => state.key}) |> URI.encode_query()
    sign = query <> "&secret_key=#{state.secret}"
    :crypto.hash(:md5, sign) |> Base.encode16()
  end

  defp validate(response) do
    case response do
      %{"error_code" => error_code} -> failure(error_code)
      %{"data" => %{"error" => error}} -> failure(error)
      %{"data" => data} -> success(data)
      %{} -> success(response)
    end
  end
end
