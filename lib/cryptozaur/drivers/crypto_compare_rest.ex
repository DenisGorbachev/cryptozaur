defmodule Cryptozaur.Drivers.CryptoCompareRest do
  use HTTPoison.Base
  use GenServer

  require OK
  import OK, only: [success: 1, failure: 1]
  import Logger
  import Cryptozaur.Utils

  @timeout 600_000
  @http_timeout 30000

  # the docs say that @requests_per_hour is 6000, but it's actually 8000
  @requests_per_second 15
  @requests_per_hour 8000
  @millis_in_hour 3_600_000
  @millis_in_second 1_000

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(opts) do
    # reset rate limitation
    ExRated.delete_bucket(__MODULE__)
    success(opts)
  end

  # Client

  def get_coin_shapshot(pid, base, quote) do
    GenServer.call(pid, {:get_coin_shapshot, base, quote}, @timeout)
  end

  def get_torches(pid, exchange, base, quote, resolution, to, limit) do
    GenServer.call(pid, {:get_torches, exchange, base, quote, resolution, to, limit}, @timeout)
  end

  def get_histohour(pid, exchange, base, quote, opts \\ %{}) do
    GenServer.call(pid, {:get_histohour, exchange, base, quote, opts}, @timeout)
  end

  def get_histoday(pid, exchange, base, quote, opts \\ %{}) do
    GenServer.call(pid, {:get_histoday, exchange, base, quote, opts}, @timeout)
  end

  def get_coins(pid) do
    GenServer.call(pid, {:get_coins}, @timeout)
  end

  def get_pairs(pid) do
    GenServer.call(pid, {:get_pairs}, @timeout)
  end

  def get_tickers_for_exchange(pid, exchange, base_list, quote_list, opts \\ %{}) do
    GenServer.call(pid, {:get_tickers_for_exchange, exchange, base_list, quote_list, opts}, @timeout)
  end

  # Server

  def handle_call({:get_torches, exchange, base, quote, resolution, to, limit}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
      after
        # call returns `limit` candles up to `toTs` (there's no `fromTs`)
        {url, aggregate} =
          cond do
            resolution >= 24 * 60 * 60 -> {"https://min-api.cryptocompare.com/data/histoday", div(resolution, 24 * 60 * 60)}
            resolution >= 60 * 60 -> {"https://min-api.cryptocompare.com/data/histohour", div(resolution, 60 * 60)}
            resolution >= 60 -> {"https://min-api.cryptocompare.com/data/histominute", div(resolution, 60)}
            true -> throw("Resolution \"#{resolution}\" is not supported")
          end

        parameters = %{
          e: exchange,
          fsym: base,
          tsym: quote,
          aggregate: aggregate,
          toTs: to,
          limit: limit
        }

        send_public_request(url, parameters)
      end

    {:reply, result, state}
  end

  def handle_call({:get_histoday, exchange, base, quote, opts}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
      after
        url = "https://min-api.cryptocompare.com/data/histoday"

        parameters =
          Map.merge(opts, %{
            e: exchange,
            fsym: base,
            tsym: quote
          })

        send_public_request(url, parameters)
      end

    {:reply, result, state}
  end

  def handle_call({:get_histohour, exchange, base, quote, opts}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
      after
        url = "https://min-api.cryptocompare.com/data/histohour"

        parameters =
          Map.merge(opts, %{
            e: exchange,
            fsym: base,
            tsym: quote
          })

        send_public_request(url, parameters)
      end

    {:reply, result, state}
  end

  def handle_call({:get_coins}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
      after
        send_public_request("https://min-api.cryptocompare.com/data/all/coinlist", %{})
      end

    {:reply, result, state}
  end

  def handle_call({:get_pairs}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
      after
        send_public_request("https://min-api.cryptocompare.com/data/all/exchanges", %{})
      end

    {:reply, result, state}
  end

  def handle_call({:get_coin_shapshot, base, quote}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
        url = "https://www.cryptocompare.com/api/data/coinsnapshot"

        parameters = %{
          fsym: base,
          tsym: quote
        }

        result = send_public_request(url, parameters)
      after
        result
      end

    {:reply, result, state}
  end

  def handle_call({:get_tickers_for_exchange, exchange, base_list, quote_list, opts}, _from, state) do
    result =
      OK.for do
        _ <- check_rate_limit()
        url = "https://min-api.cryptocompare.com/data/pricemultifull"

        parameters =
          Map.merge(opts, %{
            e: exchange,
            fsyms: base_list |> Enum.join(","),
            tsyms: quote_list |> Enum.join(",")
          })

        result = send_public_request(url, parameters)
      after
        result
      end

    {:reply, result, state}
  end

  defp send_public_request(url, parameters) do
    task =
      GenRetry.Task.async(
        fn ->
          result = get(url <> "?" <> URI.encode_query(parameters), timeout: @http_timeout, recv_timeout: @http_timeout)
          #          Apex.ap(result, numbers: false)
          case result do
            failure(%HTTPoison.Error{reason: reason}) when reason in [:timeout, :connect_timeout, :closed, :enetunreach, :nxdomain] ->
              warn("~~ CryptoCompare.Rest.send_public_request(#{inspect(url)}, #{inspect(parameters)}) # timeout")
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
      %{"Response" => "Error", "Message" => message, "Type" => type} -> failure("[#{type}] #{message}")
      %{"Response" => "Success", "Data" => data} -> success(data)
      %{"RAW" => data} -> success(data)
      data -> success(data)
    end
  end

  defp check_rate_limit do
    OK.try do
      _ <- ExRated.check_rate(__MODULE__, @millis_in_second, @requests_per_second)
      _ <- ExRated.check_rate(__MODULE__, @millis_in_hour, @requests_per_hour)
    after
      success(true)
    rescue
      _ -> failure(:rate_limit)
    end
  end
end
