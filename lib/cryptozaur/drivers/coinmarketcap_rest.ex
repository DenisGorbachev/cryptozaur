defmodule Cryptozaur.Drivers.CoinmarketcapRest do
  use HTTPoison.Base
  use GenServer

  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 30000

  @requests_per_minute 10
  @millis_in_minute 60_000

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    # reset rate limitation
    ExRated.delete_bucket(__MODULE__)
    success(state)
  end

  # Client

  def get_briefs(pid, opts \\ %{limit: 0}) do
    GenServer.call(pid, {:get_briefs, opts}, @timeout)
  end

  # Server

  def handle_call({:get_briefs, opts}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
      after
        url = "https://api.coinmarketcap.com/v1/ticker/"
        parameters = Map.take(opts, [:start, :limit, :convert])

        send_public_request(url, parameters)
      end

    {:reply, result, state}
  end

  defp send_public_request(url, parameters) do
    task =
      GenRetry.Task.async(
        fn ->
          case get(url <> "?" <> URI.encode_query(parameters), timeout: @http_timeout, recv_timeout: @http_timeout) do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ Coinmarketcap.Rest.send_public_request(#{inspect(url)}, #{inspect(parameters)}) # timeout")
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
    # no validation assumed
    success(response)
  end

  defp check_rate_limit do
    OK.try do
      _ <- ExRated.check_rate(__MODULE__, @millis_in_minute, @requests_per_minute)
    after
      success(true)
    rescue
      _ -> failure(:rate_limit)
    end
  end
end
