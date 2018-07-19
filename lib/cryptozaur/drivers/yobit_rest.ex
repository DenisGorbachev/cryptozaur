defmodule Cryptozaur.Drivers.YobitRest do
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

  def get_info(pid) do
    GenServer.call(pid, {:get_info}, @timeout)
  end

  def get_active_orders(pid, base, quote) do
    GenServer.call(pid, {:get_active_orders, base, quote}, @timeout)
  end

  def trade(pid, type, base, quote, amount, price) do
    GenServer.call(pid, {:trade, type, base, quote, amount, price}, @timeout)
  end

  # Server

  def handle_call({:get_info}, _from, state) do
    url = "https://yobit.net/tapi"
    {nonce, state} = increment_nonce(state)
    parameters = [method: "getInfo", nonce: nonce]

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:get_active_orders, base, quote}, _from, state) do
    pair = to_pair(base, quote)

    url = "https://yobit.net/tapi/"
    parameters = %{market: pair}

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  def handle_call({:trade, type, base, quote, amount, price}, _from, state) do
    url = "https://yobit.net/tapi"
    {nonce, state} = increment_nonce(state)
    parameters = [method: "Trade", pair: to_pair(base, quote), type: type, rate: Float.to_string(price), amount: Float.to_string(amount), nonce: nonce]

    result = send_private_request(url, parameters, state)

    {:reply, result, state}
  end

  #  defp send_public_request(url, parameters) do
  #    body = URI.encode_query parameters
  #
  #    OK.with do
  #      task = GenRetry.Task.async(fn ->
  #        case get(url <> "?" <> body, [], timeout: @http_timeout, recv_timeout: @http_timeout) do
  #          failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
  #            warn "~~ Yobit.Rest.send_public_request(#{inspect url}, #{inspect parameters}) # timeout"
  #            raise "retry"
  #          failure(error) -> failure(error)
  #          success(response) -> parse!(response.body) # Retry on exception (#rationale: sometimes Yobit returns "The service is unavailable" instead of proper JSON)
  #        end
  #      end, retries: 10, delay: 2_000, jitter: 0.1, exp_base: 1.1)
  #      payload = Task.await(task, @timeout)
  #      validate(payload)
  #    end
  #  end

  defp send_private_request(url, parameters, %{key: key, secret: secret}) do
    signature_data = parameters |> URI.encode_query()
    signature = :crypto.hmac(:sha512, secret, signature_data) |> Base.encode16() |> String.downcase()
    headers = [Key: key, Sign: signature]

    OK.with do
      task =
        GenRetry.Task.async(
          fn ->
            case post(url, {:form, parameters}, headers, timeout: @http_timeout, recv_timeout: @http_timeout) do
              failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
                warn("~~ Yobit.Rest.send_private_request(#{inspect(url)}, #{inspect(parameters)}) # timeout")
                raise "retry"

              failure(error) ->
                failure(error)

              # Retry on exception (#rationale: sometimes Yobit returns "The service is unavailable" instead of proper JSON)
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
  end

  defp to_pair(base, quote), do: "#{String.downcase(base)}_#{String.downcase(quote)}"

  defp validate(response) do
    case response do
      %{"success" => 1, "return" => return} -> success(return)
      %{"success" => 0, "error" => message} -> failure(message)
    end
  end
end
