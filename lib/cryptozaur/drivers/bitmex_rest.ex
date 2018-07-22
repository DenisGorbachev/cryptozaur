defmodule Cryptozaur.Drivers.BitmexRest do
  use HTTPoison.Base
  use GenServer
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 30000
  @base_url "https://www.bitmex.com"

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_trades(pid, base, quote, extra \\ %{}) do
    GenServer.call(pid, {:get_trades, base, quote, extra}, @timeout)
  end

  def get_order_book(pid, base, extra \\ %{}) do
    GenServer.call(pid, {:get_order_book, base, extra}, @timeout)
  end

  def get_balance(pid, currency) do
    GenServer.call(pid, {:get_balance, currency}, @timeout)
  end

  def get_orders(pid, extra) do
    GenServer.call(pid, {:get_orders, extra}, @timeout)
  end

  def place_order(pid, base, quote, amount, price, extra \\ %{}) do
    GenServer.call(pid, {:place_order, base, quote, amount, price, extra}, @timeout)
  end

  def delete_order(pid, order_id) do
    GenServer.call(pid, {:delete_order, order_id}, @timeout)
  end

  def change_order(pid, order_id, changes, extra \\ %{}) do
    GenServer.call(pid, {:change_order, order_id, changes, extra}, @timeout)
  end

  # Server

  def handle_call({:get_trades, base, _quote, extra}, _from, state) do
    path = "/api/v1/trade"

    parameters = Map.merge(%{symbol: base, reverse: true}, extra)

    result = send_public_request(path, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_order_book, base, extra}, _from, state) do
    path = "/api/v1/orderBook/L2"
    parameters = Map.merge(%{symbol: base}, Map.take(extra, [:depth]))

    result = send_public_request(path, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_balance, currency}, _from, state) do
    url = "/api/v1/user/wallet"
    parameters = %{currency: currency}

    result = send_private_request(:GET, url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_orders, extra}, _from, state) do
    url = "/api/v1/order"
    parameters = Map.take(extra, [:symbol])

    result = send_private_request(:GET, url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:place_order, base, quote, amount, price, extra}, _from, state) do
    url = "/api/v1/order"

    parameters =
      %{
        symbol: "#{base}#{quote}",
        orderQty: amount,
        price: price
      }
      |> Map.merge(extra)

    result = send_private_request(:POST, url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:delete_order, order_id}, _from, state) do
    url = "/api/v1/order"
    parameters = %{orderID: order_id}

    result = send_private_request(:DELETE, url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:change_order, order_id, changes, extra}, _from, state) do
    url = "/api/v1/order"
    parameters = Map.merge(extra, %{orderID: order_id})
    parameters = if Map.has_key?(changes, :price), do: Map.put(parameters, :price, changes.price), else: parameters
    parameters = if Map.has_key?(changes, :amount), do: Map.put(parameters, :orderQty, changes.amount), else: parameters

    result = send_private_request(:PUT, url, parameters, state)

    {:reply, result, state}
  end

  defp send_public_request(path, parameters) do
    body = URI.encode_query(parameters)

    task =
      GenRetry.Task.async(
        fn ->
          case get(@base_url <> path <> "?" <> body, [], timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Bitmex.Rest.send_public_request(#{inspect(path)}, #{inspect(parameters)}) # timeout")
              raise "retry"

            failure(error) ->
              failure(error)

            success(response) ->
              if value(response.headers, "X-RateLimit-Remaining") == "0" do
                {reset, ""} = Integer.parse(value(response.headers, "X-RateLimit-Reset"))
                delay = reset - now_in_seconds()
                warn("~~ Bitmex.Rest.send_public_request(#{inspect(path)}, #{inspect(parameters)}) # rate limit exceeded, sleeping for #{delay} seconds")
                Process.sleep(delay * 1000)
                raise "retry"
              else
                # Retry on exception (#rationale: sometimes Bittrex returns "The service is unavailable" instead of proper JSON)
                parse!(response.body)
              end
          end
        end,
        retries: 10,
        delay: 2_000,
        jitter: 0.1,
        exp_base: 1.1
      )

    payload = Task.await(task, @timeout)
    validate(payload)
  end

  defp send_private_request(method, path, parameters, %{key: key, secret: secret}) do
    nonce = :os.system_time(:millisecond)

    {url, data, sig} =
      case method do
        :GET ->
          query = URI.encode_query(parameters)
          uri = if parameters == %{}, do: path, else: path <> "?" <> query
          signature = :crypto.hmac(:sha256, secret, "GET" <> uri <> Integer.to_string(nonce)) |> Base.encode16()

          {@base_url <> uri, "", signature}

        _ ->
          body = Poison.encode!(parameters)
          signature = :crypto.hmac(:sha256, secret, Atom.to_string(method) <> path <> Integer.to_string(nonce) <> body) |> Base.encode16()

          {@base_url <> path, body, signature}
      end

    headers = [
      "content-type": "application/json",
      Accept: "application/json",
      "X-Requested-With": "XMLHttpRequest",
      "api-key": key,
      "api-nonce": nonce,
      "api-signature": sig
    ]

    GenRetry.Task.async(
      fn ->
        case request(method, url, data, headers, timeout: @http_timeout, recv_timeout: @http_timeout) do
          failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
            warn("~~ Bitmex.Rest.send_private_request(#{inspect(path)}, #{inspect(parameters)}) # timeout")
            raise "retry"

          failure(error) ->
            failure(error)

          # Retry on exception (#rationale: sometimes Bittrex returns "The service is unavailable" instead of proper JSON)
          success(response) ->
            parse!(response.body)
        end
      end,
      retries: 10,
      delay: 2_000,
      jitter: 0.1,
      exp_base: 1.1
    )
    |> Task.await(@timeout)
    |> validate()
  end

  defp validate(response) do
    case response do
      %{"error" => %{"message" => message}} -> failure(message)
      result -> success(result)
    end
  end
end
