defmodule Cryptozaur.Drivers.BittrexRest do
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

  def get_latest_trades(pid, base, quote) do
    GenServer.call(pid, {:get_latest_trades, base, quote}, @timeout)
  end

  def get_order_history(pid) do
    GenServer.call(pid, {:get_order_history}, @timeout)
  end

  def get_order_history(pid, base, quote) do
    GenServer.call(pid, {:get_order_history, base, quote}, @timeout)
  end

  def get_order(pid, uuid) do
    GenServer.call(pid, {:get_order, uuid}, @timeout)
  end

  def cancel(pid, uuid) do
    GenServer.call(pid, {:cancel, uuid}, @timeout)
  end

  def get_open_orders(pid) do
    GenServer.call(pid, {:get_open_orders}, @timeout)
  end

  def get_open_orders(pid, base, quote) do
    GenServer.call(pid, {:get_open_orders, base, quote}, @timeout)
  end

  def sell_limit(pid, base, quote, amount, price) do
    GenServer.call(pid, {:sell_limit, base, quote, amount, price}, @timeout)
  end

  def buy_limit(pid, base, quote, amount, price) do
    GenServer.call(pid, {:buy_limit, base, quote, amount, price}, @timeout)
  end

  def get_balances(pid) do
    GenServer.call(pid, {:get_balances}, @timeout)
  end

  def get_balance(pid, currency) do
    GenServer.call(pid, {:get_balance, currency}, @timeout)
  end

  def get_order_book(pid, base, quote) do
    get_order_book(pid, base, quote, "both")
  end

  def get_order_book(pid, base, quote, type) do
    GenServer.call(pid, {:get_order_book, base, quote, type}, @timeout)
  end

  def get_depth(pid, base, quote) do
    GenServer.call(pid, {:get_depth, base, quote}, @timeout)
  end

  def get_deposit_address(pid, currency) do
    GenServer.call(pid, {:get_deposit_address, currency}, @timeout)
  end

  def withdraw(pid, currency, amount, destination) do
    GenServer.call(pid, {:withdraw, currency, amount, destination}, @timeout)
  end

  def get_summaries(pid) do
    GenServer.call(pid, {:get_summaries}, @timeout)
  end

  # Server

  def handle_call({:get_latest_trades, base, quote}, _from, state) do
    pair = to_pair(base, quote)

    url = "https://bittrex.com/api/v1.1/public/getmarkethistory"
    parameters = %{market: pair}

    result = send_public_request(url, parameters)

    {:reply, result, state}
  end

  def handle_call({:sell_limit, base, quote, amount, price}, _from, state) do
    pair = to_pair(base, quote)

    url = "https://bittrex.com/api/v1.1/market/selllimit"
    parameters = %{market: pair, quantity: amount, rate: price}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_order_book, base, quote, type}, _from, state) do
    pair = to_pair(base, quote)

    url = "https://bittrex.com/api/v1.1/public/getorderbook"
    parameters = %{market: pair, type: type}

    result = send_public_request(url, parameters)

    {:reply, result, state}
  end

  def handle_call({:get_summaries}, _from, state) do
    url = "https://bittrex.com/api/v1.1/public/getmarketsummaries"
    parameters = %{}

    result = send_public_request(url, parameters)

    {:reply, result, state}
  end

  def handle_call({:buy_limit, base, quote, amount, price}, _from, state) do
    pair = to_pair(base, quote)

    url = "https://bittrex.com/api/v1.1/market/buylimit"
    parameters = %{market: pair, quantity: amount, rate: price}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_order_history}, _from, state) do
    url = "https://bittrex.com/api/v1.1/account/getorderhistory"
    parameters = %{}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_order_history, base, quote}, _from, state) do
    pair = to_pair(base, quote)

    url = "https://bittrex.com/api/v1.1/account/getorderhistory"
    parameters = %{market: pair}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_balances}, _from, state) do
    url = "https://bittrex.com/api/v1.1/account/getbalances"
    parameters = %{}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_balance, currency}, _from, state) do
    url = "https://bittrex.com/api/v1.1/account/getbalance"
    parameters = %{currency: currency}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_order, uuid}, _from, state) do
    url = "https://bittrex.com/api/v1.1/account/getorder"
    parameters = %{uuid: uuid}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:cancel, uuid}, _from, state) do
    url = "https://bittrex.com/api/v1.1/market/cancel"
    parameters = %{uuid: uuid}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_open_orders}, _from, state) do
    url = "https://bittrex.com/api/v1.1/market/getopenorders"
    parameters = %{}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_open_orders, base, quote}, _from, state) do
    pair = to_pair(base, quote)
    url = "https://bittrex.com/api/v1.1/market/getopenorders"
    parameters = %{market: pair}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_deposit_address, currency}, _from, state) do
    url = "https://bittrex.com/api/v1.1/account/getdepositaddress"
    parameters = %{currency: currency}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:withdraw, currency, amount, destination}, _from, state) do
    url = "https://bittrex.com/api/v1.1/account/withdraw"
    parameters = %{currency: currency, quantity: amount, address: destination}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  #  def handle_call({:get_depth, base, quote}, _from, state) do
  #    pair = to_pair base, quote
  #    url = "https://bittrex.com/Market/Index?MarketName=#{pair}"
  #    result = OK.for do
  #      response <- get(url,
  #        timeout: @timeout,
  #        recv_timeout: @timeout
  #      )
  #      buys_div = Meeseeks.one(response.body, css("div[data-bind*='orderBook.sumBuysMarket()']"))
  #      sells_div = Meeseeks.one(response.body, css("div[data-bind*='orderBook.sumSellsMarket()']"))
  #      IO.inspect(buys_div, pretty: true)
  #      {buys, _} = Float.parse(Meeseeks.text(buys_div))
  #      {sells, _} = Float.parse(Meeseeks.text(sells_div))
  #      IO.inspect(buys, pretty: true)
  #    after
  #      %{buys: buys, sells: sells}
  #    end
  #    {:reply, result, state}
  #  end

  defp send_public_request(url, parameters) do
    body = URI.encode_query(parameters)

    task =
      GenRetry.Task.async(
        fn ->
          case get(url <> "?" <> body, [], timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Bittrex.Rest.send_public_request(#{inspect(url)}, #{inspect(parameters)}) # timeout")
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

    payload = Task.await(task, @timeout)
    validate(payload)
  end

  defp send_private_request(url, parameters, %{key: key, secret: secret}) do
    nonce = :os.system_time()

    query =
      parameters
      |> Map.put("apikey", key)
      |> Map.put("nonce", nonce)
      |> URI.encode_query()

    uri = url <> "?" <> query
    signature = :crypto.hmac(:sha512, secret, uri) |> Base.encode16() |> String.downcase()

    headers = [apisign: signature]

    task =
      GenRetry.Task.async(
        fn ->
          case get(uri, headers, timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Bittrex.Rest.send_private_request(#{inspect(url)}, #{inspect(parameters)}) # timeout")
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

    payload = Task.await(task, @timeout)
    validate(payload)
  end

  defp to_pair(base, quote), do: "#{quote}-#{base}"

  defp validate(response) do
    case response do
      %{"success" => true, "result" => result} -> success(result)
      %{"message" => message} -> failure(message)
    end
  end
end
