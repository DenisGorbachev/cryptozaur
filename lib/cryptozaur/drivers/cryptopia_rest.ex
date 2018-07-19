defmodule Cryptozaur.Drivers.CryptopiaRest do
  use GenServer
  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 30000

  def start_link(state, opts \\ []) do
    state = Map.put(state, :nonce, :os.system_time(:milli_seconds))
    GenServer.start_link(__MODULE__, state, opts)
  end

  # Client

  def get_tickers(pid) do
    GenServer.call(pid, {:get_tickers}, @timeout)
  end

  # Server

  def handle_call({:get_tickers}, _from, state) do
    path = "/api/GetMarkets"
    params = %{}
    result = get(path, params)
    {:reply, result, state}
  end

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
    url = "https://www.cryptopia.co.nz" <> path
    # TODO: remove :insecure
    options = options ++ [hackney: [:insecure]]

    fn ->
      case HTTPoison.request(method, url, body, headers, options) do
        failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
          warn("~~ CryptopiaRest.request(#{inspect(method)}, #{inspect(url)}, #{inspect(body)}, #{inspect(headers)}, #{inspect(options)}) # timeout")
          raise "retry"

        failure(error) ->
          failure(error)

        success(response) ->
          parse!(response.body)
      end
    end
  end

  defp signature_headers(path, params, nonce, state) do
    # Elixir automatically arranges map keys in alphabetic order
    query = params |> URI.encode_query()
    sign = path <> "/#{nonce}/" <> query
    signature = :crypto.hmac(:sha256, state.secret, Base.encode64(sign)) |> Base.encode16() |> String.downcase()
    ["KC-API-KEY": state.key, "KC-API-NONCE": nonce, "KC-API-SIGNATURE": signature]
  end

  defp validate(response) do
    case response do
      %{"Success" => true, "Message" => _null, "Data" => data} -> success(data)
      %{"Success" => false, "Message" => message} -> failure(message)
    end
  end
end
