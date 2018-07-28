defmodule Cryptozaur.Drivers.LeverexRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 90000
  @retries (Mix.env() == :test && 0) || 10
  @default_limit 1000

  def start_link(state, opts \\ []) do
    state =
      %{
        url: "https://www.leverex.io",
        nonce: :os.system_time(:milli_seconds)
      }
      |> Map.merge(Application.get_env(:cryptozaur, :leverex, []) |> to_map())
      |> Map.merge(state)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_info(pid, extra \\ []) do
    GenServer.call(pid, {:get_info, extra}, @timeout)
  end

  def get_balances(pid, extra \\ []) do
    GenServer.call(pid, {:get_balances, extra}, @timeout)
  end

  def get_orders(pid, symbol \\ nil, extra \\ []) do
    GenServer.call(pid, {:get_orders, symbol, extra}, @timeout)
  end

  def place_order(pid, symbol, amount, price, extra \\ []) do
    GenServer.call(pid, {:place_order, symbol, amount, price, extra}, @timeout)
  end

  def cancel_order(pid, uid, extra \\ []) do
    GenServer.call(pid, {:cancel_order, uid, extra}, @timeout)
  end

  def handle_call({:get_info, extra}, _from, state) do
    path = "/api/v1/info"
    params = [] ++ extra
    {result, state} = get(path, params, build_headers(), build_options(), state)
    {:reply, result, state}
  end

  def handle_call({:get_balances, extra}, _from, state) do
    path = "/api/v1/my/balances"
    params = [] ++ extra
    {result, state} = get(path, params, build_headers(), build_options(is_signed: true), state)
    {:reply, result, state}
  end

  def handle_call({:get_orders, symbol, extra}, _from, state) do
    path = "/api/v1/my/orders"
    params = [symbol: symbol] ++ extra
    {result, state} = get_with_pagination(path, params, build_headers(), build_options(is_signed: true), state)
    {:reply, result, state}
  end

  def handle_call({:place_order, symbol, amount, price, extra}, _from, state) do
    path = "/api/v1/my/orders"
    params = []
    body = extra |> Keyword.merge(symbol: symbol, called_amount: to_string(amount), limit_price: to_string(price))
    {result, state} = post(path, body, params, build_headers(), build_options(is_signed: true), state)
    {:reply, result, state}
  end

  def handle_call({:cancel_order, uid, extra}, _from, state) do
    path = "/api/v1/my/orders/#{uid}/cancel"
    params = [] ++ extra
    body = []
    {result, state} = put(path, body, params, build_headers(), build_options(is_signed: true), state)
    {:reply, result, state}
  end

  defp get_with_pagination(path, params, headers, options, state) do
    with {success(objects), state} <- get(path, params, headers, options, state) do
      if length(objects) < Keyword.get(params, :limit, @default_limit) do
        {success(objects), state}
      else
        last_id = objects |> List.last() |> Map.get("id")
        params = params |> Keyword.put(:to_id, last_id - 1)

        with {success(objects_next), state} <- get_with_pagination(path, params, headers, options, state) do
          {success(objects ++ objects_next), state}
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

  defp put(path, body, params, headers, options, state) do
    request(:put, path, body, params, headers, options, state)
  end

  defp request(method, path, body, params, headers, options, state) do
    GenRetry.Task.async(request_task(method, path, body, params, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout], state), retries: @retries, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body, params, headers, options, state) do
    fn ->
      {method, path, body, params, headers, options, state} =
        if options[:is_signed] do
          sign(method, path, body, params, headers, options, state)
        else
          {method, path, body, params, headers, options, state}
        end

      result =
        case HTTPoison.request(method, state.url <> path, {:form, body}, headers, options ++ [params: params]) do
          failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
            warn("~~ LeverexRest.request(#{inspect(method)}, #{inspect(state.url <> path)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
            raise "retry"

          failure(error) ->
            failure(error)

          success(response) ->
            parse!(response.body)
        end

      {result, state}
    end
  end

  defp build_headers(headers \\ []) do
    headers
  end

  defp build_options(options \\ [is_signed: false]) do
    options
  end

  defp sign(method, path, body, params, headers, options, %{key: key, secret: secret} = state) do
    {auth_nonce, state} = increment_nonce(state)
    data = [auth_nonce: auth_nonce] |> Keyword.merge(body) |> Keyword.merge(params)
    auth_params = Signaturex.sign(key, secret, method, path, data)
    headers = headers |> Keyword.merge("X-Key": auth_params["auth_key"], "X-Signature": auth_params["auth_signature"], "X-Nonce": auth_nonce |> to_string(), "X-Timestamp": auth_params["auth_timestamp"] |> to_string())
    {method, path, body, params, headers, options, state}
  end

  defp validate({result, state}) do
    case result do
      %{"type" => _type, "details" => _details} = error -> {failure(error), state}
      data -> {success(data), state}
    end
  end
end
