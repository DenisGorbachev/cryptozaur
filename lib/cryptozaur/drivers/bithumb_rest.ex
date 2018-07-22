defmodule Cryptozaur.Drivers.BithumbRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 60000
  @base_url "https://api.bithumb.com"

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

  # Server

  def handle_call({:get_ticker, base, _quote}, _from, state) do
    path = "/public/ticker/#{base}"
    params = %{}
    result = get(path, params)
    {:reply, result, state}
  end

  def handle_call({:get_tickers}, _from, state) do
    path = "/public/ticker/ALL"
    result = get(path)
    {:reply, result, state}
  end

  defp get(path, params \\ [], headers \\ [], options \\ []) do
    request(:get, path, "", headers, options ++ [params: params])
  end

  defp request(method, path, body \\ "", headers \\ [], options \\ []) do
    GenRetry.Task.async(fn -> request_task(method, path, body, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout]) end, retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body \\ "", headers \\ [], options \\ []) do
    url = @base_url <> path

    case HTTPoison.request(method, url, body, headers, options) do
      failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed] ->
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

  defp validate(response) do
    case response do
      %{"status" => "0000", "data" => data} -> success(data)
      %{"status" => error_code} -> failure(error_code)
    end
  end
end
