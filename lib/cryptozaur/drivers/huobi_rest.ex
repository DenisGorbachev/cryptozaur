defmodule Cryptozaur.Drivers.HuobiRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1, ~>>: 2]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 60000

  # rate limits:
  # - 100 req / 10 sec
  # https://github.com/huobiapi/API_Docs_en/wiki/Request_Process

  # https://github.com/huobiapi/API_Docs_en/wiki/REST_Reference

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  # to provide universal REST interface it's necessary to fetch current account ID before the first request
  def init(params) do
    # don't fetch account id for public driver
    if params.key == :public do
      success(params)
    else
      OK.try do
        account_id <- get_trading_account_id(params)
      after
        Map.put(params, :trading_account_id, account_id) |> success()
      rescue
        error -> {:stop, error}
      end
    end
  end

  # Client

  def get_symbols(pid) do
    GenServer.call(pid, {:get_symbols}, @timeout)
  end

  def get_ticker(pid, base, quote) do
    GenServer.call(pid, {:get_ticker, base, quote}, @timeout)
  end

  # 2000 = max
  def get_latest_trades(pid, base, quote, size \\ 2000) do
    GenServer.call(pid, {:get_latest_trades, base, quote, size}, @timeout)
  end

  def get_accounts(pid) do
    GenServer.call(pid, {:get_accounts}, @timeout)
  end

  def get_balances(pid) do
    GenServer.call(pid, {:get_balances}, @timeout)
  end

  def place_order(pid, base, quote, type, amount, opts \\ %{}) do
    GenServer.call(pid, {:place_order, base, quote, type, amount, opts}, @timeout)
  end

  def get_orders(pid, opts \\ %{}) do
    GenServer.call(pid, {:get_orders, opts}, @timeout)
  end

  def cancel_order(pid, order_id) do
    GenServer.call(pid, {:cancel_order, order_id}, @timeout)
  end

  # Server

  defp get_trading_account_id(params) do
    if Map.has_key?(params, :trading_account_id) do
      success(params.trading_account_id)
    else
      account = do_get_accounts(params) ~>> Enum.find(&(&1["type"] == "spot" and &1["state"] == "working"))
      if account, do: success(Integer.to_string(account["id"])), else: failure("No active trading account")
    end
  end

  # https://github.com/huobiapi/API_Docs_en/wiki/REST_Reference#get-v1commonsymbols-----get-all-the-trading-assets
  def handle_call({:get_symbols}, _from, state) do
    path = "/v1/common/symbols"
    params = %{}
    result = get(path, params)
    {:reply, result, state}
  end

  def handle_call({:get_accounts}, _from, state) do
    result = do_get_accounts(state)
    {:reply, result, state}
  end

  defp do_get_accounts(state) do
    path = "/v1/account/accounts"
    signed_get(state, path)
  end

  def handle_call({:get_balances}, _from, %{trading_account_id: account_id} = state) do
    path = "/v1/account/accounts/#{account_id}/balance"
    result = signed_get(state, path)
    {:reply, result, state}
  end

  def handle_call({:get_orders, opts}, _from, state) do
    path = "/v1/order/orders"

    params =
      Map.merge(
        %{
          "states" => "pre-submitted,submitting,submitted,submitted,partial-filled,partial-canceled,filled,canceled"
        },
        opts
      )

    result = signed_get(state, path, params)
    {:reply, result, state}
  end

  def handle_call({:cancel_order, order_id}, _from, state) do
    path = "/v1/order/orders/#{order_id}/submitcancel"
    result = signed_post(state, path)
    {:reply, result, state}
  end

  def handle_call({:place_order, base, quote, type, amount, opts}, _from, %{trading_account_id: account_id} = state) do
    path = "/v1/order/orders/place"

    params = %{
      "account-id" => account_id,
      "symbol" => to_symbol(base, quote),
      "type" => type,
      "amount" => Float.to_string(amount),
      # spot trade (not margin) by default
      "source" => Map.get(opts, :api, "api")
    }

    params = if opts.price, do: Map.put(params, "price", Float.to_string(opts.price)), else: params

    # note parameters are not signed!
    result = signed_post(state, path, params)
    {:reply, result, state}
  end

  # https://github.com/huobiapi/API_Docs_en/wiki/REST_Reference#get-marketdetail---market-detail-in-24-hours
  def handle_call({:get_ticker, base, quote}, _from, state) do
    path = "/market/detail/merged"
    params = %{symbol: to_symbol(base, quote)}
    result = get(path, params)
    {:reply, result, state}
  end

  def handle_call({:get_latest_trades, base, quote, size}, _from, state) do
    path = "/market/history/trade"
    params = %{symbol: to_symbol(base, quote), size: size}
    result = get(path, params)
    {:reply, result, state}
  end

  defp get(path, params \\ %{}, headers \\ [], options \\ []) do
    request(:get, path, "", headers, options ++ [params: params])
  end

  #  defp post(path, body \\ "", params \\ %{}, headers \\ [], options \\ []) do
  #    request(:post, path, body, headers, options ++ [params: params])
  #  end
  #
  defp signed_get(state, path, params \\ %{}, headers \\ [], options \\ []) do
    signed_params = sign_params(state, "GET", path, params)
    request(:get, path, "", headers, options ++ [params: signed_params])
  end

  defp signed_post(state, path, params \\ %{}, headers \\ [], options \\ []) do
    # note: POST body parameters are never signed!
    body = Poison.encode!(params)
    signed_params = sign_params(state, "POST", path, %{})

    request(:post, path, body, headers, options ++ [params: signed_params])
  end

  defp request(method, path, body \\ "", headers \\ [], options \\ []) do
    # not application/x-www-form-urlencoded as it's written in docs
    headers = [{"Content-Type", "application/json"} | headers]

    GenRetry.Task.async(request_task(method, path, body, headers, options ++ [timeout: @http_timeout, recv_timeout: @http_timeout]), retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
    |> Task.await(@timeout)
    |> validate()
  end

  defp request_task(method, path, body \\ "", headers \\ [], options \\ []) do
    url = "https://api.huobi.pro" <> path

    fn ->
      case HTTPoison.request(method, url, body, headers, options) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ Huobi.Rest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          parse!(response.body)
      end
    end
  end

  defp sign_params(state, method, path, params) do
    enriched_params =
      Map.merge(params, %{
        "AccessKeyId" => state.key,
        "SignatureMethod" => "HmacSHA256",
        "SignatureVersion" => 2,
        "Timestamp" => NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()
      })

    Map.put(enriched_params, "Signature", get_signature(method, path, enriched_params, state.secret))
  end

  defp get_signature(method, path, params, secret) do
    # Elixir automatically arranges map keys in alphabetic order
    query = URI.encode_query(params)
    sign = method <> "\n" <> "api.huobi.pro\n" <> path <> "\n" <> query
    :crypto.hmac(:sha256, secret, sign) |> Base.encode64()
  end

  defp validate(response) do
    case response do
      %{"status" => "ok", "tick" => tick} -> success(tick)
      %{"status" => "ok", "data" => data} -> success(data)
      %{"status" => "error", "err-code" => code, "err-msg" => message} -> failure("[#{code}] #{message}")
    end
  end

  defp to_symbol(base, quote) do
    "#{base}#{quote}" |> String.downcase()
  end
end
