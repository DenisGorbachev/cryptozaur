defmodule Cryptozaur.Drivers.PoloniexRest do
  use HTTPoison.Base
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @moduledoc """
  Wrapper around public Poloniex API
  """

  # For some reason, Poloniex requires large timeouts
  @timeout 600_000
  @http_timeout 200_000

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_trade_history(pid, base, quote, start, finish) do
    # set GenServer call timeout to `infinity` since the request may time fuck a lot of time
    GenServer.call(pid, {:get_trade_history, base, quote, start, finish}, @timeout)
  end

  # Server

  def handle_call({:get_trade_history, base, quote, naive_start, naive_finish}, _from, state) do
    pair = to_pair(base, quote)

    start = naive_start |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    finish = naive_finish |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

    parameters = %{currencyPair: pair, start: start} |> Map.put(:end, finish)

    # set HTTP timeout to`infinity` since the request may time fuck a lot of time
    result = send_public_request("returnTradeHistory", parameters, recv_timeout: @http_timeout, timeout: @http_timeout)

    {:reply, result, state}
  end

  #  @doc """
  #  Returns aggragated balances for all currencies
  #  """
  #  def get_balances(key, secret) do
  #    send_private_request(key, secret, %{
  #      command: "returnCompleteBalances",
  #    })
  #    ~>> Enum.map(&aggregate_balance/1)
  #    |> success
  #  end
  #
  #  @doc """
  #  Places an order.
  #
  #  Use positive :amount for `buy` orders and negative for `sell` ones
  #
  #  Available options:
  #  - fillOrKill: 1
  #  - immediateOrCancel: 1
  #  - postOnly: 1
  #  """
  #  def place_order(key, secret, base, quot, rate, amount, options \\ []) do
  #    command = if amount > 0, do: "buy", else: "sell"
  #    send_private_request(key, secret, Map.merge(Map.new(options), %{
  #      command: command,
  #      currencyPair: to_pair(base, quot),
  #      rate: rate,
  #      amount: abs(amount)
  #    }))
  #  end
  #
  #  @doc """
  #  Moves an existing order.
  #
  #  It's not allowed to change sign(amount) i.e. change order type (`sell` to `buy` and vise versa)
  #
  #  Available options:
  #  - immediateOrCancel: 1
  #  - postOnly: 1
  #  """
  #  def move_order(key, secret, orderNumber, rate, amount, options \\ []) do
  #    send_private_request(key, secret, Map.merge(Map.new(options), %{
  #      command: "moveOrder",
  #      orderNumber: orderNumber,
  #      rate: rate,
  #      amount: abs(amount)
  #    }))
  #  end
  #
  #  @doc """
  #  Cancels an order
  #  """
  #  def cancel_order(key, secret, orderNumber, options \\ []) do
  #    send_private_request(key, secret, Map.merge(Map.new(options), %{
  #      command: "cancelOrder",
  #      orderNumber: orderNumber,
  #    }))
  #  end
  #
  #  @doc """
  #  Returns open orders for given currency pair
  #  """
  #  def get_orders(key, secret, base, quot, options \\ []) do
  #    send_private_request(key, secret, Map.merge(Map.new(options), %{
  #      command: "returnOpenOrders",
  #      currencyPair: to_pair(base, quot),
  #    }))
  #  end
  #
  #  defp aggregate_balance({symbol, values}) do
  #    overall = String.to_float(values["available"]) + String.to_float(values["onOrders"])
  #    {symbol, overall}
  #  end

  defp validate(response) do
    case response do
      %{"error" => error} -> failure(error)
      _ -> success(response)
    end
  end

  defp send_public_request(command, parameters, opts) do
    query =
      parameters
      |> Map.put(:command, command)

    get("/public", query, opts)
  end

  #  defp send_private_request(key, secret, parameters) do
  #    body = parameters
  #          |> Map.put_new(:nonce, :erlang.system_time()) # set default nonce if absent
  #          |> URI.encode_query
  #
  #    signanure = sign(body, secret)
  #    headers = [
  #      {"Key", key},
  #      {"Sign", signanure},
  #      {"Content-Type", "application/x-www-form-urlencoded"},
  #    ]
  #      # TODO: implement retry
  #      response <- post("https://poloniex.com/tradingApi", body, headers)
  #      payload = parse!(response.body)
  #      validate(payload)
  #  end

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
    url = "https://poloniex.com" <> path

    fn ->
      case HTTPoison.request(method, url, body, headers, options) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ PoloniexRest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          parse!(response.body)
      end
    end
  end

  defp to_pair(base, quot), do: quot <> "_" <> base

  #  defp sign(body, secret) do
  #    :crypto.hmac(:sha512, secret, body)
  #    |> Base.encode16()
  #    |> String.downcase()
  #  end
end
