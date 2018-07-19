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
      |> Map.put(:nonce, :os.system_time(:milli_seconds))
      |> Map.put_new(:url, "https://leverex.io/api")

    GenServer.start_link(__MODULE__, state, opts)
  end

  # Client

  def get_balances(pid) do
    GenServer.call(pid, {:get_balances}, @timeout)
  end

  def place_order(pid, symbol, amount, price, params \\ %{}) do
    GenServer.call(pid, {:place_order, symbol, amount, price, params}, @timeout)
  end

  def handle_call({:get_balances}, _from, %{url: url} = state) do
    path = "/v1/my/balances"
    params = %{}
    {headers, state} = signature_headers(:get, path, params, state)
    Apex.ap(headers, numbers: false)
    Apex.ap(url, numbers: false)
    result = get(url <> path, params, headers)
    {:reply, result, state}
  end

  def handle_call({:place_order, symbol, amount, price, extra}, _from, %{url: url} = state) do
    path = "/v1/my/orders"
    params = %{}
    body = extra |> Map.merge(%{symbol: symbol, amount: amount, price: price})
    {headers, state} = signature_headers(:post, path, body, state)
    result = post(url <> path, Poison.encode!(body), params, headers)
    {:reply, result, state}
  end

  defp get(url, params \\ [], headers \\ [], options \\ []) do
    request(:get, url, "", headers, options ++ [params: params])
  end

  defp post(url, body \\ "", params \\ [], headers \\ [], options \\ []) do
    request(:post, url, body, headers, options ++ [params: params])
  end

  defp request(method, url, body \\ "", headers \\ [], options \\ []) do
    GenRetry.Task.async(request_task(method, url, body, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout]), retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, url, body \\ "", headers \\ [], options \\ []) do
    fn ->
      case HTTPoison.request(method, url, body, headers, options) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ LeverexRest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          parse!(response.body)
      end
    end
  end

  defp base_url() do
    Application.get_env(:cryptozaur, :leverex, []) |> Keyword.get(:base_url, "https://leverex.io/api")
  end

  defp signature_headers(method, path, params, %{key: key, secret: secret} = state) do
    {auth_nonce, state} = increment_nonce(state)
    params = params |> Map.put(:auth_nonce, auth_nonce)
    auth_params = Signaturex.sign(key, secret, method, path, params)
    {["X-Key": auth_params["auth_key"], "X-Signature": auth_params["auth_signature"], "X-Nonce": auth_nonce |> to_string(), "X-Timestamp": auth_params["auth_timestamp"] |> to_string()], state}
  end

  defp validate(response) do
    case response do
      %{"type" => _type, "details" => _details} = error -> failure(error)
      data -> success(data)
    end
  end
end
