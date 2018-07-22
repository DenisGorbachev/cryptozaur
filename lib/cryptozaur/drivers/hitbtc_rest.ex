defmodule Cryptozaur.Drivers.HitbtcRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 60000
  @max_limit 1000

  def start_link(state, opts \\ []) do
    state = Map.put(state, :nonce, :os.system_time(:milli_seconds))
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  # `from` & `till` may be either timestamps or
  def get_trades(pid, base, quote, from \\ nil, till \\ nil, extra \\ %{}) do
    extra = defaults(extra, %{sort: "DESC", by: "timestamp", limit: @max_limit, offset: nil})
    GenServer.call(pid, {:get_trades, base, quote, from, till, extra}, @timeout)
  end

  def get_orderbook(pid, base, quote, limit \\ 0) do
    GenServer.call(pid, {:get_orderbook, base, quote, limit}, @timeout)
  end

  # Server

  # https://api.hitbtc.com/#trades
  def handle_call({:get_trades, base, quote, from, till, extra}, _from, state) do
    path = "/api/2/public/trades/#{to_symbol(base, quote)}"
    params = Map.merge(extra, %{from: from, till: till})
    result = get(path, params)
    {:reply, result, state}
  end

  # https://api.hitbtc.com/#orderbook
  def handle_call({:get_orderbook, base, quote, limit}, _from, state) do
    path = "/api/2/public/orderbook/#{to_symbol(base, quote)}"
    params = %{limit: limit}
    result = get(path, params)
    {:reply, result, state}
  end

  defp get(path, params, headers \\ [], options \\ []) do
    request(:get, path, "", headers, options ++ [params: params])
  end

  #  defp post(path, body \\ "", params \\ [], headers \\ [], options \\ []) do
  #    request(:post, path, body, headers, options ++ [params: params])
  #  end
  #
  defp request(method, path, body, headers, options) do
    GenRetry.Task.async(request_task(method, path, body, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout]), retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body, headers, options) do
    url = "https://api.hitbtc.com" <> path

    fn ->
      case HTTPoison.request(method, url, body, headers, options) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ Hitbtc.Rest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          case parse!(response.body) do
            %{"error" => %{"code" => 500, "message" => "Internal Server Error"}} -> raise "retry"
            result -> result
          end
      end
    end
  end

  #  defp signature_headers(path, params, nonce, state) do
  #    query = params |> URI.encode_query # Elixir automatically arranges map keys in alphabetic order
  #    sign = path <> "/#{nonce}/" <> query
  #    signature = :crypto.hmac(:sha256, state.secret, Base.encode64(sign)) |> Base.encode16 |> String.downcase
  #    ["KC-API-KEY": state.key, "KC-API-NONCE": nonce, "KC-API-SIGNATURE": signature]
  #  end

  defp validate(response) do
    case response do
      %{"error" => %{"code" => code, "message" => message, "description" => description}} -> failure("[#{code}] #{message}; #{description}")
      %{"error" => %{"code" => code, "message" => message}} -> failure("[#{code}] #{message}")
      data -> success(data)
    end
  end

  defp to_symbol(base, quote) do
    "#{base}#{quote}"
  end
end
