defmodule Cryptozaur.Drivers.BitmexWebsocket do
  @moduledoc false

  use GenServer
  import Logger
  import OK, only: [success: 1, failure: 1]

  @defaults %{
    key: :public,
    secret: nil,
    host: "www.bitmex.com",
    port: 443,
    path: "/realtime",
    secure: true
    # _auth_nonce - is used only for testing purposes
  }

  @timeout 3000
  # should be more than @timeout to prevent throwing Task/:timeout exception
  @task_timeout 10000

  def start_link(params \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, Map.merge(@defaults, params), opts)
  end

  def init(%{key: key, host: host, port: port, path: path, secure: secure} = params) do
    OK.try do
      listener = watch_for(key, :welcome)
      socket <- Socket.Web.connect(host, port, path: path, secure: secure)
      _ <- start_listener(socket, key)
      _ <- await(listener)

      _ <-
        if key != :public do
          auth(socket, key, Map.get(params, :secret), Map.get(params, :_auth_nonce, :os.system_time(:millisecond)))
        else
          success(nil)
        end
    after
      success(Map.put(params, :socket, socket))
    rescue
      "connection refused" -> {:stop, "Unable to connect to ws#{if secure, do: "s", else: ""}://#{host}:#{port}#{path}"}
      {:no_message, :welcome} -> {:stop, "Welcome message hasn't been received within a specified interval"}
      {:no_message, :auth} -> {:stop, "Auth message hasn't been received within a specified interval"}
      error -> {:stop, error}
    end
  end

  # Client

  def subscribe_trades(pid, base, quote), do: subscribe_on(pid, "trade", base, quote)

  def subscribe_orderbook(pid, base, quote), do: subscribe_on(pid, "orderBookL2", base, quote)

  def subscribe_orders(pid, base, quote), do: subscribe_on(pid, "order", base, quote)

  def subscribe_positions(pid, base, quote), do: subscribe_on(pid, "position", base, quote)

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

  # Server

  def handle_call({:get_descriptor, channel, base, quote}, _from, %{key: key} = state) do
    pair = to_pair(base, quote)
    {:reply, success(get_descriptor(key, {:data, channel, pair})), state}
  end

  def handle_call({:subscribe, channel, base, quote}, _from, %{socket: socket, key: key} = state) do
    pair = to_pair(base, quote)
    topic = "#{channel}:#{pair}"

    OK.try do
      listener = watch_for(key, {:subscribe, channel, pair})
      _ <- send_message(socket, %{op: "subscribe", args: [topic]})
      result <- await(listener)
      _ <- result
    after
      debug(~s(Bitmex has subscribed on type "#{topic} for #{key}"))
      _descriptor = get_descriptor(key, {:data, channel, pair})
      {:reply, success(nil), state}
    rescue
      {:no_message, {:subscribe, ^channel, ^pair}} -> {:reply, failure("Subscribe confirmation for #{pair} hasn't been received within a specified interval for key #{key}"), state}
      error -> {:reply, failure(error), state}
    end
  end

  defp subscribe(descriptor) do
    Registry.register(Cryptozaur.WebsocketStreams, descriptor, nil)
  end

  defp watch_for(key, event) do
    Task.async(fn ->
      OK.for do
        # debug "Subscribe on #{inspect get_descriptor(key, event)}"
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

  defp await(listener) do
    Task.await(listener, @task_timeout)
  end

  defp auth(socket, key, secret, nonce) do
    signature = calculate_signature(secret, nonce)

    OK.for do
      listener = watch_for(key, :auth)
      _ <- send_message(socket, %{op: "authKey", args: [key, nonce, signature]})
      response <- await(listener)
    after
      response
    end
  end

  defp calculate_signature(secret, nonce) do
    :crypto.hmac(:sha256, secret, "GET/realtime" <> Integer.to_string(nonce)) |> Base.encode16()
  end

  defp start_listener(socket, key), do: Task.start_link(fn -> listen(socket, key) end)

  defp listen(socket, key) do
    OK.try do
      message <- receive_message(socket)
    after
      debug("Received #{inspect(message)}")
      handle_message(message, key)
      listen(socket, key)
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

  defp handle_message(%{"subscribe" => genome, "success" => true}, key) do
    [channel, pair] = String.split(genome, ":")

    send_event(key, {:subscribe, channel, pair}, success(nil))
  end

  defp handle_message(%{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"}, key) do
    send_event(key, :welcome)
  end

  defp handle_message(%{"error" => error, "request" => %{"args" => [key | _]}}, key) do
    send_event(key, :auth, failure(error))
  end

  defp handle_message(%{"success" => true, "request" => %{"args" => [key | _]}}, key) do
    send_event(key, :auth, success(nil))
  end

  defp handle_message(%{"error" => error, "request" => %{"args" => [genome], "op" => "subscribe"}, "status" => 400}, key) do
    [channel, pair] = String.split(genome, ":")

    send_event(key, {:subscribe, channel, pair}, failure(error))
  end

  defp handle_message(%{"filter" => %{"symbol" => pair}, "action" => "partial", "table" => channel, "data" => data} = _message, key) do
    send_event(key, {:data, channel, pair}, %{insert: data, initial: true})
  end

  defp handle_message(%{"action" => action_string, "table" => channel, "data" => [entry | _] = data}, key) do
    pair = fetch_pair(entry)
    action = String.to_atom(action_string)
    send_event(key, {:data, channel, pair}, Map.new([{action, data}]))
  end

  defp handle_message(message, key) do
    warn("Uncaught websocket message received: #{inspect(message)} for key #{key}")
  end

  defp fetch_pair(%{"symbol" => pair}), do: pair
  defp fetch_pair(%{"currency" => base, "quoteCurrency" => quote}), do: "#{String.upcase(base)}#{String.upcase(quote)}"

  defp send_event(key, event, payload \\ nil) do
    # debug "send event #{inspect get_descriptor(key, event)} with payload #{inspect payload}"
    Registry.dispatch(Cryptozaur.WebsocketStreams, get_descriptor(key, event), &Enum.each(&1, fn {pid, _} -> send(pid, {event, payload}) end))
  end

  defp get_descriptor(key, event) do
    {__MODULE__, key, event}
  end

  defp to_pair(base, quote), do: base <> quote
end
