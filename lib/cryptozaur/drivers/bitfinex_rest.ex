defmodule Cryptozaur.Drivers.BitfinexRest do
  use HTTPoison.Base
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 30000

  def start_link(state, opts \\ []) do
    state = Map.put(state, :nonce, DateTime.to_unix(DateTime.utc_now()))
    GenServer.start_link(__MODULE__, state, opts)
  end

  # Client

  def get_trades(pid, base, quote, extra \\ %{}) do
    GenServer.call(pid, {:get_trades, base, quote, extra}, @timeout)
  end

  def get_symbols(pid) do
    GenServer.call(pid, {:get_symbols}, @timeout)
  end

  def get_ticker(pid, base, quote) do
    GenServer.call(pid, {:get_ticker, base, quote}, @timeout)
  end

  def get_tickers(pid) do
    GenServer.call(pid, {:get_tickers}, @timeout)
  end

  def get_candles(pid, base, quote, resolution, extra \\ %{}) do
    GenServer.call(pid, {:get_candles, base, quote, resolution, extra}, @timeout)
  end

  def get_order_book(pid, base, quote, extra \\ %{}) do
    GenServer.call(pid, {:get_order_book, base, quote, extra}, @timeout)
  end

  def get_balances(pid, extra \\ %{}) do
    GenServer.call(pid, {:get_balances, extra}, @timeout)
  end

  # Server

  def handle_call({:get_trades, base, quote, extra}, _from, state) do
    pair = to_pair(base, quote)
    path = "/v2/trades/#{pair}/hist"
    parameters = Map.take(extra, [:start, :end, :limit, :sort])
    result = send_public_request(path, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_symbols}, _from, state) do
    path = "/v1/symbols"
    result = send_public_request(path)
    {:reply, result, state}
  end

  def handle_call({:get_ticker, base, quote}, _from, state) do
    path = "/v2/ticker/#{to_pair(base, quote)}"
    params = %{}
    result = send_public_request(path)
    {:reply, result, state}
  end

  def handle_call({:get_tickers}, _from, state) do
    {_, result, _} = handle_call({:get_symbols}, _from, state)
    success(symbols) = result
    symbols = symbols |> Enum.map(&from_symbols(&1)) |> Enum.join(",")
    # this seems extremely hacky but when sending symbols string separated by commas, the parser changes it
    path = "/v2/tickers?symbols=#{symbols}"
    result = send_public_request(path)
    {:reply, result, state}
  end

  def handle_call({:get_candles, base, quote, resolution, extra}, _from, state) do
    pair = to_pair(base, quote)

    path = "/v2/candles/trade:#{resolution}m:#{pair}/hist"
    parameters = Map.take(extra, [:start, :end, :limit, :sort])

    result = send_public_request(path, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_order_book, base, quote, extra}, _from, state) do
    pair = to_pair(base, quote)

    precision = Map.get(extra, :precision, "P0")

    path = "/v2/book/#{pair}/#{precision}"
    parameters = Map.take(extra, [:len])

    result = send_public_request(path, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_balances, extra}, _from, state) do
    path = "/v2/auth/r/wallets"
    {nonce, state} = increment_nonce(state)
    parameters = extra
    headers = [{"bfx-nonce", nonce}]

    result = send_private_request(path, parameters, headers, state)

    {:reply, result, state}
  end

  def handle_call({:get_symbols, base, quote}, _from, state) do
    path = "/v2/ticker/#{to_pair(base, quote)}"
    params = %{}
    result = send_public_request(path)
    {:reply, result, state}
  end

  defp send_public_request(path, parameters \\ []) do
    body = URI.encode_query(parameters)
    path = "https://api.bitfinex.com" <> path

    if String.length(body) > 0 do
      path = path <> "?" <> body
    end

    OK.with do
      task =
        GenRetry.Task.async(
          fn ->
            case get(path, timeout: @http_timeout, recv_timeout: @http_timeout) do
              failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
                warn("~~ Bitfinex.Rest.send_public_request(#{inspect(path)}, #{inspect(parameters)}) # timeout")
                raise "retry"

              failure(error) ->
                failure(error)

              success(response) ->
                # Retry on exception
                parse!(response.body)
                |> handle_rate_limit()
            end
          end,
          retries: 10,
          delay: 6_000,
          jitter: 0.1,
          exp_base: 1.1
        )

      payload = Task.await(task, @timeout)
      validate(payload)
    end
  end

  defp send_private_request(path, parameters, headers, %{key: key, secret: secret}) do
    nonce = headers |> value("bfx-nonce")
    body = parameters |> Poison.encode!()
    signature_data = "/api/#{path}#{nonce}#{body}"
    Apex.ap(body, numbers: false)

    signature = :crypto.hmac(:sha384, secret, signature_data) |> Base.encode16() |> String.downcase()
    headers = headers ++ [{"bfx-apikey", key}, {"bfx-signature", signature}]
    IO.puts(inspect(headers))

    # debug
    headers = []

    OK.with do
      task =
        GenRetry.Task.async(
          fn ->
            case post("https://api.bitfinex.com" <> path, body, headers, timeout: @http_timeout, recv_timeout: @http_timeout) do
              failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
                warn("~~ Bitfinex.Rest.send_private_request(#{inspect(path)}, #{inspect(parameters)}) # timeout")
                raise "retry"

              failure(error) ->
                failure(error)

              success(response) ->
                # Retry on exception
                parse!(response.body)
                |> handle_rate_limit()
            end
          end,
          retries: 10,
          delay: 6_000,
          jitter: 0.1,
          exp_base: 1.1
        )

      payload = Task.await(task, @timeout)
      validate(payload)
    end
  end

  defp from_symbols(pair) do
    pair = pair |> String.split_at(3)
    base = String.upcase(elem(pair, 0))
    quote = String.upcase(elem(pair, 1))
    to_pair(base, quote)
  end

  defp to_pair(base, quote), do: "t#{base}#{quote}"

  defp to_symbol(base, quote), do: "#{base}#{quote}"

  defp validate(response) do
    case response do
      ["error", 10010, _] -> failure(:rate_limit)
      ["error", errcode, message] -> failure("#{errcode}: #{message}")
      _ -> success(response)
    end
  end

  # V1
  defp handle_rate_limit(%{"error" => "ERR_RATE_LIMIT"}) do
    warn("~~ Bitfinex.Rest # rate limit")
    raise "retry"
  end

  # V2
  defp handle_rate_limit(["error", errcode, _]) when errcode in [10010, 11010] do
    warn("~~ Bitfinex.Rest # rate limit")
    raise "retry"
  end

  defp handle_rate_limit(other), do: other
end
