defmodule Cryptozaur.Drivers.BitfinexWebsocket do
  @moduledoc false

  @defaults %{
    key: :public,
    secret: nil,
    host: "api.bitfinex.com",
    port: 443,
    path: "/ws/2",
    secure: true
    # _auth_nonce - is used only for testing purposes
  }

  @timeout 3000
  # should be more than @timeout to prevent throwing Task/:timeout exception
  @task_timeout 10000

  use GenServer
  import Logger
  import Cryptozaur.Utils, only: [all_ok: 2]
  import OK, only: [success: 1, failure: 1]

  def start_link(params \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, Map.merge(@defaults, params), opts)
  end

  def init(%{key: key, host: host, port: port, path: path, secure: secure} = params) do
    OK.try do
      socket <- initialise_connection(key, host, port, path, secure)
      #      _ <- if key != :public do
      #        auth(socket, key, Map.get(params, :secret), Map.get(params, :_auth_nonce, :os.system_time(:millisecond)))
      #      else
      #        success(nil)
      #      end
    after
      params
      |> Map.put(:socket, socket)
      |> Map.put(:channels, %{})
      |> success()
    rescue
      "connection refused" -> {:stop, "Unable to connect to ws#{if secure, do: "s", else: ""}://#{host}:#{port}#{path}"}
      {:no_message, :welcome} -> {:stop, "Welcome message hasn't been received within a specified interval"}
      {:no_message, :auth} -> {:stop, "Auth message hasn't been received within a specified interval"}
      error -> {:stop, error}
    end
  end

  # Client

  def subscribe_trades(pid, base, quote), do: subscribe_on(pid, "trades", base, quote)

  def subscribe_ticker(pid, base, quote), do: subscribe_on(pid, "ticker", base, quote)

  def subscribe_orderbook(pid, base, quote), do: subscribe_on(pid, "book", base, quote)

  #  def subscribe_orders(pid, pair), do: subscribe_on(pid, "order", pair)
  #
  #  def subscribe_positions(pid, pair), do: subscribe_on(pid, "position", pair)

  defp subscribe_on(pid, channel, base, quote) do
    OK.for do
      descriptor <- GenServer.call(pid, {:get_descriptor, channel, base, quote})
      subscription <- subscribe(descriptor)
    after
      OK.try do
        _ <- GenServer.call(pid, {:subscribe, channel, base, quote})
      after
        success(subscription)
      rescue
        error ->
          stop_subscription(subscription)
          failure(error)
      end
    end
  end

  defp stop_subscription(pid) do
    flag = Process.flag(:trap_exit, true)
    Process.exit(pid, :kill)

    receive do
      # that's fine
      {:EXIT, ^pid, :killed} ->
        :noop

      _ ->
        raise ":EXIT message expected"
    end

    Process.flag(:trap_exit, flag)
  end

  defp initialise_connection(key, host, port, path, secure) do
    OK.for do
      listener = watch_for(key, :welcome)
      socket <- Socket.Web.connect(host, port, path: path, secure: secure)
      _ <- start_listener(socket, key, self())
      _ <- await_message(listener)
    after
      socket
    end
  end

  defp initialise_subscription(channel, pair, socket, key) do
    OK.for do
      listener = watch_for(key, {:subscribe, channel, pair})
      _ <- send_message(socket, %{event: "subscribe", channel: channel, symbol: pair})
      result <- await_message(listener)
    after
      result
    end
  end

  # Server

  #  def handle_call({:track_trades, pair}, _, %{socket: socket, channels: channels} = state) do
  #    Socket.Web.send! socket, {:text, Poison.encode! %{
  #      event: "subscribe",
  #      channel: "trades",
  #      symbol: pair
  #    }}
  #
  #    channel = wait_for_subscription_message socket, state
  #    newState = %{state | channels: Map.put(channels, channel, pair)}
  #
  #    debug "Bitfinex has registered channel ##{channel} as #{pair}"
  #
  #    {:reply, :ok, newState, @timeout}
  #  end

  #  def handle_call({:auth, key, secret}, _, %{socket: socket} = state) do
  #    nonce = :os.system_time()
  #    payload = "AUTH#{nonce}"
  #    signature = :crypto.hmac(:sha384, secret, payload) |> Base.encode16 |> String.downcase
  #
  #    data = %{
  #      key: key,
  #      authSig: signature,
  #      authNonce: nonce,
  #      authPayload: payload,
  #      event: "auth",
  #      filter: ["trading", "balance", "wallet"]
  #    }
  #
  #    Socket.Web.send! socket, {:text, Poison.encode! data}
  #
  #    result = wait_for_auth_message socket, state
  #
  #    {:reply, result, state, @timeout}
  #  end

  #  def handle_info(:timeout, %{socket: socket} = state) do
  #    # set zero timeout to prevent blocking
  #    case receive_message(socket, timeout: 0) do
  #      nil -> :ok; # no messages in a queue
  #      data -> handle_message data, state
  #    end
  #
  #    {:noreply, state, @timeout}
  #  end

  #  def wait_for_subscription_message(socket, state) do
  #      case receive_message(socket) do
  #      [channel, [_ | _]] -> channel
  #      data ->
  #        handle_message data, state
  #        wait_for_subscription_message(socket, state)
  #    end
  #  end
  #
  #  def wait_for_auth_message(socket, state) do
  #    case receive_message(socket) do
  #      %{"event" => "auth", "msg" => message, "status" => "FAILED"} ->
  #        {:error, message}
  #      %{"event" => "auth", "status" => "OK"} ->
  #        :ok
  #      data ->
  #        handle_message data, state
  #        wait_for_auth_message(socket, state)
  #    end
  #  end

  # used only for interval purposes
  def handle_call({:register_channel, channel_id, channel, pair}, _from, %{channels: channels, key: _key} = state) do
    updated_state = %{state | channels: Map.put(channels, channel_id, {:data, channel, pair})}

    {:reply, nil, updated_state}
  end

  # used only for interval purposes
  def handle_call({:get_channel_event, channel_id}, _from, %{channels: channels} = state) do
    {:reply, channels[channel_id], state}
  end

  def handle_call({:get_descriptor, channel, base, quote}, _from, %{key: key} = state) do
    pair = to_pair(base, quote)
    descriptor = get_descriptor(key, {:data, channel, pair})
    {:reply, success(descriptor), state}
  end

  def handle_call({:subscribe, channel, base, quote}, _from, %{socket: socket, key: key} = state) do
    pair = to_pair(base, quote)

    OK.try do
      _ <- initialise_subscription(channel, pair, socket, key)
    after
      debug(~s(Bitfinex has subscribed on "#{channel}/#{pair} for #{key}"))
      {:reply, success(nil), state}
    rescue
      {:no_message, {:subscribe, ^channel, ^pair}} -> {:reply, failure("Subscribe confirmation for #{channel}/#{pair} hasn't been received within a specified interval for key #{key}"), state}
      error -> {:reply, failure(error), state}
    end
  end

  def handle_call({:reconnect}, _from, %{key: key, host: host, port: port, path: path, secure: secure, channels: channels} = state) do
    OK.try do
      socket <- initialise_connection(key, host, port, path, secure)

      _ <-
        channels
        |> Map.values()
        |> Enum.map(fn {:data, channel, pair} -> initialise_subscription(channel, pair, socket, key) end)
        |> all_ok(success(nil))
    after
      {:reply, success(nil), %{state | socket: socket}}
    rescue
      e -> {:error, e, state}
    end
  end

  defp subscribe(descriptor) do
    Registry.register(Cryptozaur.WebsocketStreams, descriptor, nil)
  end

  defp watch_for(key, event) do
    Task.async(fn ->
      OK.for do
        debug("Subscribe on #{inspect(get_descriptor(key, event))}")
        _ <- Registry.register(Cryptozaur.WebsocketStreams, get_descriptor(key, event), nil)
      after
        receive do
          {^event, data} -> success(data)
          message -> failure("Wrong message received: expected #{inspect(event)}, actual #{inspect(message)}")
        after
          @timeout -> failure({:no_message, event})
        end
      end
    end)
  end

  defp await_message(listener) do
    Task.await(listener, @task_timeout)
  end

  #  defp auth(socket, key, secret, nonce) do
  #    signature = calculate_signature(secret, nonce)
  #
  #    OK.for do
  #      listener = watch_for(key, :auth)
  #      _ <- send_message(socket, %{op: "authKey", args: [key, nonce, signature]})
  #      response <- await_message(listener)
  #    after
  #      response
  #    end
  #  end
  #
  defp start_listener(socket, key, driver), do: Task.start_link(fn -> listen(socket, key, driver) end)

  defp listen(socket, key, driver) do
    OK.try do
      message <- receive_message(socket)
    after
      debug("Received #{inspect(message)}")
      handle_message(message, key, driver)
      listen(socket, key, driver)
    rescue
      # connection closed
      {:close, :abnormal, nil} ->
        Process.exit(self(), :terminated)

      error ->
        error("Enable to receive message from Bitmex websocket: #{inspect(error)}")
    end
  end

  defp send_message(socket, message) do
    OK.for do
      data <- Poison.encode(message)
    after
      case Socket.Web.send(socket, {:text, data}) do
        :ok -> success(nil)
        error -> failure(error)
      end
    end
  end

  defp receive_message(socket, opts \\ []) do
    OK.for do
      message <- Socket.Web.recv(socket, opts)
    after
      case message do
        {:text, text} -> Cryptozaur.Utils.parse(text)
        error -> failure(error)
      end
    end
  end

  def handle_message(%{"event" => "info", "version" => 2}, key, _driver) do
    send_event(key, :welcome)
  end

  def handle_message(%{"code" => 20051, "event" => "info", "msg" => "Stopping. Please try to reconnect"}, _key, driver) do
    GenServer.call(driver, {:reconnect})
    Process.exit(self(), :terminated)
  end

  def handle_message(%{"channel" => channel, "code" => _error_code, "event" => "error", "msg" => message, "pair" => _, "symbol" => pair}, key, _driver) do
    send_event(key, {:subscribe, channel, pair}, failure(message))
  end

  def handle_message(%{"chanId" => channel_id, "channel" => channel, "event" => "subscribed", "pair" => pair}, key, driver) do
    # it's important to send event BEFORE call `register_channel`
    send_event(key, {:subscribe, channel, pair}, success(nil))

    GenServer.call(driver, {:register_channel, channel_id, channel, pair})
  end

  def handle_message([_channel_id, "hb"], _key, _driver) do
    # heartbeat
  end

  def handle_message([channel_id, data], key, driver) do
    channel_event = GenServer.call(driver, {:get_channel_event, channel_id})
    send_event(key, channel_event, data)
  end

  # trade-specific handler
  def handle_message([_channel_id, "tu", _data], _key, _driver) do
    # this event is duplicated by "te" event
  end

  def handle_message([channel_id, "te", data], key, driver) do
    channel_event = GenServer.call(driver, {:get_channel_event, channel_id})
    send_event(key, channel_event, data)
  end

  #  def handle_message([_, "te", _], _, _) do
  #    # trade has been executed.
  #    # this event is superseded by "tu" event which always follows by this one
  #  end
  #
  #  def handle_message([channel, "tu", [uid, timestamp, amount, price] = data], _, _) do
  #    debug "Trade: [#{uid}] at #{timestamp}: #{amount} #{price}"
  #
  #    pair = Map.fetch!(channels, channel)
  #
  #    Registry.dispatch Registry.Data.Bitfinex, pair, fn entries -> for {pid, _} <- entries, do: send(pid, {:trade, data}) end
  #  end
  #
  #  def handle_message([0, "tu", _], _, _) do
  #    # user-related trade has been updated
  #  end
  #
  #  def handle_message([0, "wu", data], _, _) do
  #    # user wallet balance has been updated
  #
  #    debug "User wallet has been updated #{inspect data}"
  #  end
  #
  #  def handle_message([0, "on", _], _, _) do
  #    # user order has been created
  #    # this event is superseded by "ou" event which always follows this one
  #  end
  #
  #  def handle_message([0, "ou", data], _, _) do
  #    # user order has been updated
  #
  #    debug "User order has been updated #{inspect data}"
  #  end
  #
  #  def handle_message([0, "oc", data], _, _) do
  #    # user order has been closed or completed
  #
  #    debug "User order has been closed #{inspect data}"
  #  end
  #
  #  def handle_message([0, "ws", data], _, _) do
  #    # wallets snapshot
  #
  #    debug "Current wallets #{inspect data}"
  #  end
  #
  #  def handle_message([0, "os", data], _, _) do
  #    # orders snapshot
  #
  #    debug "Current orders #{inspect data}"
  #  end
  #
  #  def handle_message([0, "ps", data], _, _) do
  #    # positions snapshot
  #
  #    debug "Current positions #{inspect data}"
  #  end
  #
  #  def handle_message([_, "hb", _], _, _) do
  #    # heartbeats
  #  end
  #
  #  def handle_message([_, "hb"], _, _) do
  #    # heartbeats
  #  end

  def handle_message(data, _, _) do
    warn("Unknown message from Bitfinex: #{inspect(data)}")
  end

  defp send_event(key, event, payload \\ nil) do
    debug("send event #{inspect(get_descriptor(key, event))} with payload #{inspect(payload)}")
    Registry.dispatch(Cryptozaur.WebsocketStreams, get_descriptor(key, event), &Enum.each(&1, fn {pid, _} -> send(pid, {event, payload}) end))
  end

  defp get_descriptor(key, event) do
    {__MODULE__, key, event}
  end

  defp to_pair(base, quote), do: base <> quote
end
