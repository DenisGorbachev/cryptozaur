defmodule Cryptozaur.Drivers.LeverexRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 90000

  def start_link(state, opts \\ []) do
    state =
      state
      |> Map.put(:url, "https://www.leverex.io")
      |> Map.put(:nonce, :os.system_time(:milli_seconds))
      |> Map.merge(Application.get_env(:cryptozaur, :leverex, []) |> to_map())

    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_balances(pid) do
    GenServer.call(pid, {:get_balances}, @timeout)
  end

  def place_order(pid, symbol, amount, price, params \\ %{}) do
    GenServer.call(pid, {:place_order, symbol, amount, price, params}, @timeout)
  end

  def handle_call({:get_balances}, _from, state) do
    path = "/api/v1/my/balances"
    params = []
    {result, state} = get(path, params, build_headers(), build_options(is_signed: true), state)
    {:reply, result, state}
  end

  def handle_call({:place_order, symbol, amount, price, extra}, _from, state) do
    path = "/api/v1/my/orders"
    params = []
    body = extra |> Map.merge(symbol: symbol, amount: amount, price: price)
    {result, state} = post(path, body, params, build_headers(), build_options(is_signed: true), state)
    {:reply, result, state}
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
    fn ->
      {method, path, body, params, headers, options, state} =
        if options[:is_signed] do
          sign(method, path, body, params, headers, options, state)
        else
          {method, path, body, params, headers, options, state}
        end

      body = if is_list(body) or is_map(body), do: Poison.encode!(body), else: body

      result =
        case HTTPoison.request(method, state.url <> path, body, headers, options ++ [params: params]) do
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

  defp build_options(options \\ []) do
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
