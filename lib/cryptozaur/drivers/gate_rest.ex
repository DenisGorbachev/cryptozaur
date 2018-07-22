defmodule Cryptozaur.Drivers.GateRest do
  use HTTPoison.Base
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 30000

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_tickers(pid) do
    GenServer.call(pid, {:get_tickers}, @timeout)
  end

  def get_balance(pid) do
    GenServer.call(pid, {:get_balance}, @timeout)
  end

  # Server

  def handle_call({:get_tickers}, _from, state) do
    url = "https://data.gate.io/api2/1/tickers"
    parameters = %{}

    result = get(url, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_balance}, _from, %{key: key, secret: secret} = state) do
    url = "https://api.gate.io/api2/1/private/balances"
    parameters = %{}

    headers = [{"KEY", key}, {"SIGN", generate_secret(secret, parameters)}]
    result = post(url, parameters, headers)

    {:reply, result, state}
  end

  defp generate_secret(secret, params) do
    hamc_sha512(secret, URI.encode_query(params))
  end

  defp hamc_sha512(key, what) do
    :crypto.hmac(:sha512, key, what) |> Base.encode16() |> String.downcase()
  end

  defp get(url, parameters, headers \\ []) do
    body = URI.encode_query(parameters)

    perform_request(fn ->
      # Gate requires `ssl: [{:versions, [:'tlsv1.2']}]`
      HTTPoison.get(url <> "?" <> body, headers, timeout: @http_timeout, recv_timeout: @http_timeout, ssl: [{:versions, [:"tlsv1.2"]}])
    end)
  end

  defp post(url, parameters, headers) do
    body = URI.encode_query(parameters)

    perform_request(fn ->
      # Gate requires `ssl: [{:versions, [:'tlsv1.2']}]`
      HTTPoison.post(url, body, headers, timeout: @http_timeout, recv_timeout: @http_timeout, ssl: [{:versions, [:"tlsv1.2"]}])
    end)
  end

  defp perform_request(request_function) do
    task =
      GenRetry.Task.async(
        fn ->
          case request_function.() do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Gate.Rest.perform_request # timeout")
              raise "retry"

            failure(error) ->
              failure(error)

            # Retry on exception
            success(response) ->
              parse!(response.body)
          end
        end,
        retries: 10,
        delay: 2_000,
        jitter: 0.1,
        exp_base: 1.1
      )

    success(Task.await(task, @timeout))
  end
end
