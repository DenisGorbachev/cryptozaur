defmodule Cryptozaur.Drivers.BlockRest do
  use HTTPoison.Base
  use GenServer

  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  # no actual limit per page!
  @limit 100_000

  @timeout 600_000
  @http_timeout 60000

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Client

  def get_tickers(params) do
    with {:ok, data} <- send_public_request("https://data.block.cc/api/v1/tickers", params) do
      {:ok, data["list"]}
    end
  end

  def get_markets do
    send_public_request("https://data.block.cc/api/v1/markets")
  end

  # Server

  defp send_public_request(url, parameters \\ %{}) do
    parameters = Map.put_new(parameters, :size, @limit)

    task =
      GenRetry.Task.async(
        fn ->
          case get(url <> "?" <> URI.encode_query(parameters), timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ BlockRest.send_public_request(#{inspect(url)}, #{inspect(parameters)}) because of #{reason} # timeout")
              raise "retry"

            failure(error) ->
              failure(error)

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

  defp validate(response) do
    case response do
      %{"code" => 0, "message" => "success", "data" => data} -> success(data)
      %{"code" => code, "message" => error} -> failure("#{code}: #{error}")
    end
  end
end
