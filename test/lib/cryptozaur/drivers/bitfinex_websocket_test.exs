defmodule Cryptozaur.Drivers.BitfinexWebsocketTest do
  use ExUnit.Case, async: false
  import OK, only: [success: 1, failure: 1]

  alias Cryptozaur.Drivers.BitfinexWebsocket, as: Websocket

  @host "localhost"
  # random port to prevent errors with "port is busy"
  @zero_port 0
  @path "/"
  # shouldn't be true since "localhost" doesn't have certificates
  @secure false

  defmodule TestServer do
    use GenServer

    import OK, only: [success: 1, failure: 1]

    def start_link(params) do
      GenServer.start_link(__MODULE__, params, [])
    end

    def init(%{port: port, secure: secure}) do
      socket = Socket.Web.listen!(port, secure: secure)

      success(%{socket: socket})
    end

    def get_port(pid) do
      GenServer.call(pid, :get_port)
    end

    def listen(pid) do
      GenServer.cast(pid, :listen)
    end

    def send_message(pid, message) do
      GenServer.call(pid, {:send, message})
    end

    def expect_message(pid, message) do
      GenServer.call(pid, {:expect, message})
    end

    def handle_cast(:listen, %{socket: socket} = state) do
      # accept connection
      server = Socket.Web.accept!(socket)
      # accept enstablished client
      Socket.Web.accept!(server)

      {:noreply, Map.put(state, :server, server)}
    end

    def handle_call(:get_port, _from, %{socket: socket} = state) do
      {:reply, :inet.port(socket.socket), state}
    end

    def handle_call({:send, message}, _from, %{server: server} = state) do
      # :ok
      response = Socket.Web.send(server, {:text, Poison.encode!(message)})

      {:reply, response, state}
    end

    def handle_call({:expect, expect}, _from, %{server: server} = state) do
      OK.try do
        message <- Socket.Web.recv(server)
      after
        case message do
          {:text, actual} ->
            assert Poison.encode!(expect) == actual

          # connection closed
          {:close, :abnormal, nil} ->
            nil
        end

        {:reply, success(nil), state}
      rescue
        error -> {:reply, failure(error), state}
      end
    end
  end

  def init do
    success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
    success(port) = TestServer.get_port(server)
    :ok = TestServer.listen(server)

    task = Task.async(fn -> Websocket.start_link(%{port: port, host: @host, path: @path, secure: @secure}) end)
    #    task = Task.async(fn -> Websocket.start_link() end)

    TestServer.send_message(server, %{"event" => "info", "version" => 2})

    success(client) = Task.await(task, 10_000)

    %{
      client: client,
      server: server
    }
  end

  setup do
    success(_) = start_supervised({Registry, [id: Cryptozaur.WebsocketStreams, keys: :duplicate, name: Cryptozaur.WebsocketStreams]})
    :ok
  end

  describe "Initialization" do
    setup do
      Process.flag(:trap_exit, true)
      :ok
    end

    test "can connect (success)" do
      init()
    end

    test "can connect (failure, no response)" do
      assert failure("Unable to connect to ws://localhost:3333/") == Websocket.start_link(%{port: 3333, host: @host, path: @path, secure: @secure})
    end

    test "can connect (failure, no required message)" do
      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
      success(port) = TestServer.get_port(server)
      :ok = TestServer.listen(server)

      task =
        Task.async(fn ->
          Process.flag(:trap_exit, true)
          Websocket.start_link(%{port: port, host: @host, path: @path, secure: @secure})
        end)

      assert failure("Welcome message hasn't been received within a specified interval") == Task.await(task)
    end

    #    test "can authenticate (success)" do
    #      key = "apiKey"
    #      secret = "secret"
    #      nonce = 123123123
    #
    #      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
    #      success(port) = TestServer.get_port(server)
    #      :ok = TestServer.listen(server)
    #      task = Task.async(fn ->
    #        Process.flag :trap_exit, true
    #        Websocket.start_link(%{
    #          port: port, host: @host, path: @path, secure: @secure, key: key, secret: secret,
    #          _auth_nonce: nonce,
    #        })
    #      end)
    #      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
    #      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
    #      TestServer.send_message(server,  %{"request" => %{"args" => [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"], "op" => "authKey"}, "success" => true})
    #      success(_) = Task.await(task)
    #    end
    #
    #    test "can authenticate (failure, no required message)" do
    #      key = "apiKey"
    #      secret = "secret"
    #      nonce = 123123123
    #
    #      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
    #      success(port) = TestServer.get_port(server)
    #      :ok = TestServer.listen(server)
    #      task = Task.async(fn ->
    #        Process.flag :trap_exit, true
    #        Websocket.start_link(%{
    #          port: port, host: @host, path: @path, secure: @secure, key: key, secret: secret,
    #          _auth_nonce: nonce,
    #        }) end)
    #      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
    #      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
    #      assert failure("Auth message hasn't been received within a specified interval") == Task.await(task)
    #    end
    #
    #    test "can authenticate (failure, bad api key)" do
    #      key = "apiKey"
    #      secret = "secret"
    #      nonce = 123123123
    #
    #      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
    #      success(port) = TestServer.get_port(server)
    #      :ok = TestServer.listen(server)
    #      task = Task.async(fn ->
    #        Process.flag :trap_exit, true
    #        Websocket.start_link(%{
    #          port: port, host: @host, path: @path, secure: @secure, key: key, secret: secret,
    #          _auth_nonce: nonce,
    #        }) end)
    #
    #      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
    #      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
    #      TestServer.send_message(server, %{"error" => "Invalid API Key.", "meta" => %{}, "request" => %{"args" => ["apiKey", 123123123, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"], "op" => "authKey"}, "status" => 401})
    #      assert failure("Invalid API Key.") == Task.await(task)
    #    end
    #
    #    test "can authenticate (failure, bad api signature)" do
    #      key = "apiKey"
    #      secret = "secret"
    #      nonce = 123123123
    #
    #      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
    #      success(port) = TestServer.get_port(server)
    #      :ok = TestServer.listen(server)
    #      task = Task.async(fn ->
    #        Process.flag :trap_exit, true
    #        Websocket.start_link(%{
    #          port: port, host: @host, path: @path, secure: @secure, key: key, secret: secret,
    #          _auth_nonce: nonce,
    #        }) end)
    #      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
    #      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
    #      TestServer.send_message(server, %{"error" => "Signature not valid.", "meta" => %{}, "request" => %{"args" => ["apiKey", 123123123, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"], "op" => "authKey"}, "status" => 401})
    #      assert failure("Signature not valid.") == Task.await(task)
    #    end
  end

  # use "orderbook" subscribtion as an example
  describe "Request/Common" do
    setup do
      init()
    end

    test "can successfully subscribe", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "BTC", "USD")
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 229, "channel" => "book", "event" => "subscribed", "freq" => "F0", "len" => "25", "pair" => "BTCUSD", "prec" => "P0", "symbol" => "tBTCUSD"})

      success(_) = Task.await(task)
    end

    test "can't ssubscribe because of no response", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "BTC", "USD")
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})

      assert failure("Subscribe confirmation for book/BTCUSD hasn't been received within a specified interval for key public") == Task.await(task)
    end

    test "can't subscribe because of wrong inputs", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "BTC", "DGT")
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCDGT"})
      TestServer.send_message(server, %{"channel" => "book", "code" => 10300, "event" => "error", "msg" => "symbol: invalid", "pair" => "TCDGT", "symbol" => "BTCDGT"})

      assert failure("symbol: invalid") == Task.await(task)
    end

    test "can't subscribe twice", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "BTC", "USD")
          Websocket.subscribe_orderbook(client, "BTC", "USD")
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 229, "channel" => "book", "event" => "subscribed", "freq" => "F0", "len" => "25", "pair" => "BTCUSD", "prec" => "P0", "symbol" => "tBTCUSD"})
      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"channel" => "book", "code" => 10301, "event" => "error", "msg" => "subscribe: dup", "pair" => "TCUSD", "symbol" => "BTCUSD"})

      assert failure("subscribe: dup") == Task.await(task)
    end

    test "receive initial data dump after subscribtion", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orderbook(client, "BTC", "USD")

          assert_receive {{:data, "book", "BTCUSD"}, [[8375.10000000, 3, 6.47784002], [8372, 1, 1.19540000]]}
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 229, "channel" => "book", "event" => "subscribed", "freq" => "F0", "len" => "25", "pair" => "BTCUSD", "prec" => "P0", "symbol" => "tBTCUSD"})
      TestServer.send_message(server, [229, [[8375.10000000, 3, 6.47784002], [8372, 1, 1.19540000]]])
      Task.await(task)
    end

    test "can successfully reconnect to existing channels", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "BTC", "USD")
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 229, "channel" => "book", "event" => "subscribed", "freq" => "F0", "len" => "25", "pair" => "BTCUSD", "prec" => "P0", "symbol" => "tBTCUSD"})
      TestServer.send_message(server, %{"code" => 20051, "event" => "info", "msg" => "Stopping. Please try to reconnect"})
      :ok = TestServer.listen(server)
      TestServer.send_message(server, %{"event" => "info", "version" => 2})
      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})

      success(_) = Task.await(task)
    end
  end

  describe "Request/Orderbook" do
    setup do
      init()
    end

    test "receives level changes", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orderbook(client, "BTC", "USD")

          assert_receive {{:data, "book", "BTCUSD"}, [8375.10000000, 3, 6.47784002]}
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "book", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 229, "channel" => "book", "event" => "subscribed", "freq" => "F0", "len" => "25", "pair" => "BTCUSD", "prec" => "P0", "symbol" => "tBTCUSD"})
      TestServer.send_message(server, [229, [8375.10000000, 3, 6.47784002]])
      Task.await(task)
    end
  end

  describe "Request/Trades" do
    setup do
      init()
    end

    test "receives new trades", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_trades(client, "BTC", "USD")

          assert_receive {{:data, "trades", "BTCUSD"}, [194_057_340, 1_518_428_177_185, 0.00400000, 8745.30000000]}
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "trades", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 213, "channel" => "trades", "event" => "subscribed", "pair" => "BTCUSD", "symbol" => "tBTCUSD"})
      TestServer.send_message(server, [213, "te", [194_057_340, 1_518_428_177_185, 0.00400000, 8745.30000000]])
      Task.await(task)
    end

    test "ignores trades with `tu` event type", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_trades(client, "BTC", "USD")
          refute_receive _, 1_000
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "trades", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 213, "channel" => "trades", "event" => "subscribed", "pair" => "BTCUSD", "symbol" => "tBTCUSD"})
      TestServer.send_message(server, [213, "tu", [194_057_340, 1_518_428_177_185, 0.00400000, 8745.30000000]])
      Task.await(task)
    end
  end

  describe "Request/Ticker" do
    setup do
      init()
    end

    test "receives ticker", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_ticker(client, "BTC", "USD")

          assert_receive {{:data, "ticker", "BTCUSD"}, [9924.60000000, 32.88608832, 9925.20000000, 56.76687968, 115.80000000, 0.01180000, 9925, 70991.51188893, 10271, 9470.30000000]}
        end)

      TestServer.expect_message(server, %{event: "subscribe", channel: "ticker", symbol: "BTCUSD"})
      TestServer.send_message(server, %{"chanId" => 1, "channel" => "ticker", "event" => "subscribed", "pair" => "BTCUSD", "symbol" => "tBTCUSD"})
      TestServer.send_message(server, [1, [9924.60000000, 32.88608832, 9925.20000000, 56.76687968, 115.80000000, 0.01180000, 9925, 70991.51188893, 10271, 9470.30000000]])
      Task.await(task)
    end
  end
end
