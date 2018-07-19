defmodule Cryptozaur.Drivers.BitmexWebsocketTest do
  use ExUnit.Case, async: false
  import OK, only: [success: 1, failure: 1]

  alias Cryptozaur.Drivers.BitmexWebsocket, as: Websocket

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
          _ ->
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

    TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})

    success(client) = Task.await(task)

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

    test "can authenticate (success)" do
      key = "apiKey"
      secret = "secret"
      nonce = 123_123_123

      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
      success(port) = TestServer.get_port(server)
      :ok = TestServer.listen(server)

      task =
        Task.async(fn ->
          Process.flag(:trap_exit, true)

          Websocket.start_link(%{
            port: port,
            host: @host,
            path: @path,
            secure: @secure,
            key: key,
            secret: secret,
            _auth_nonce: nonce
          })
        end)

      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
      TestServer.send_message(server, %{"request" => %{"args" => [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"], "op" => "authKey"}, "success" => true})
      success(_) = Task.await(task)
    end

    test "can authenticate (failure, no required message)" do
      key = "apiKey"
      secret = "secret"
      nonce = 123_123_123

      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
      success(port) = TestServer.get_port(server)
      :ok = TestServer.listen(server)

      task =
        Task.async(fn ->
          Process.flag(:trap_exit, true)

          Websocket.start_link(%{
            port: port,
            host: @host,
            path: @path,
            secure: @secure,
            key: key,
            secret: secret,
            _auth_nonce: nonce
          })
        end)

      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
      assert failure("Auth message hasn't been received within a specified interval") == Task.await(task)
    end

    test "can authenticate (failure, bad api key)" do
      key = "apiKey"
      secret = "secret"
      nonce = 123_123_123

      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
      success(port) = TestServer.get_port(server)
      :ok = TestServer.listen(server)

      task =
        Task.async(fn ->
          Process.flag(:trap_exit, true)

          Websocket.start_link(%{
            port: port,
            host: @host,
            path: @path,
            secure: @secure,
            key: key,
            secret: secret,
            _auth_nonce: nonce
          })
        end)

      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
      TestServer.send_message(server, %{"error" => "Invalid API Key.", "meta" => %{}, "request" => %{"args" => ["apiKey", 123_123_123, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"], "op" => "authKey"}, "status" => 401})
      assert failure("Invalid API Key.") == Task.await(task)
    end

    test "can authenticate (failure, bad api signature)" do
      key = "apiKey"
      secret = "secret"
      nonce = 123_123_123

      success(server) = TestServer.start_link(%{port: @zero_port, secure: @secure})
      success(port) = TestServer.get_port(server)
      :ok = TestServer.listen(server)

      task =
        Task.async(fn ->
          Process.flag(:trap_exit, true)

          Websocket.start_link(%{
            port: port,
            host: @host,
            path: @path,
            secure: @secure,
            key: key,
            secret: secret,
            _auth_nonce: nonce
          })
        end)

      TestServer.send_message(server, %{"info" => "Welcome to the BitMEX Realtime API.", "version" => "1.2.0"})
      TestServer.expect_message(server, %{op: "authKey", args: [key, nonce, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"]})
      TestServer.send_message(server, %{"error" => "Signature not valid.", "meta" => %{}, "request" => %{"args" => ["apiKey", 123_123_123, "1713F3EEAE80EB667F93E0CF993D8BF6F9E55276BD6B16897FF3F5E3EC0A2013"], "op" => "authKey"}, "status" => 401})
      assert failure("Signature not valid.") == Task.await(task)
    end
  end

  describe "Request/Orderbook" do
    setup do
      init()
    end

    test "can subscribe on order book (success)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "XBT", "USD")
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})

      success(_) = Task.await(task)
    end

    test "can subscribe on order book (failure, no response)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "XBT", "USD")
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})

      assert failure("Subscribe confirmation for XBTUSD hasn't been received within a specified interval for key public") == Task.await(task)
    end

    test "can subscribe on order book (failure, wrong pair)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orderbook(client, "XBT", "BTC")
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTBTC"]})
      TestServer.send_message(server, %{"error" => "Unknown or expired symbol.", "meta" => %{}, "request" => %{"args" => ["orderBookL2:XBTBTC"], "op" => "subscribe"}, "status" => 400})

      assert failure("Unknown or expired symbol.") == Task.await(task)
    end

    #    test "can subscribe on order book twice (success, no error)", %{client: client, server: server} do
    #      task = Task.async(fn ->
    #        Websocket.subscribe_orderbook(client, "XBT", "USD")
    #        Websocket.subscribe_orderbook(client, "XBT", "USD")
    #      end)
    #
    #      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
    #      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})
    #      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
    #      TestServer.send_message(server, %{"error" => "You are already subscribed to this topic: orderBookL2:XBTUSD", "meta" => %{}, "request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "status" => 400})
    #
    #      success(_) = Task.await(task)
    #    end

    test "can receive messages after subscribtion (initial `partial` message)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orderbook(client, "XBT", "USD")

          assert_receive {{:data, "orderBookL2", "XBTUSD"}, %{insert: [%{"id" => 8_790_000_000, "price" => 100_000, "side" => "Sell", "size" => 1501, "symbol" => "XBTUSD"}]}}, 1_000
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})
      TestServer.send_message(server, %{"action" => "partial", "attributes" => %{"id" => "sorted", "symbol" => "grouped"}, "data" => [%{"id" => 8_790_000_000, "price" => 100_000, "side" => "Sell", "size" => 1501, "symbol" => "XBTUSD"}], "filter" => %{"symbol" => "XBTUSD"}, "foreignKeys" => %{"side" => "side", "symbol" => "instrument"}, "keys" => ["symbol", "id", "side"], "table" => "orderBookL2", "types" => %{"id" => "long", "price" => "float", "side" => "symbol", "size" => "long", "symbol" => "symbol"}})
      Task.await(task)
    end

    #    test "can receive messages after subscribtion (subsciption has been activated before)", %{client: client, server: server} do
    #      task = Task.async(fn ->
    #        success(_) = Websocket.subscribe_orderbook(client, "XBT", "USD")
    #        success(_) = Websocket.subscribe_orderbook(client, "XBT", "USD")
    #
    #        Process.sleep(100)
    #        assert_receive {{:data, "orderBookL2", "XBTUSD"}, %{insert: [%{"id" => 8790000000, "price" => 100000, "side" => "Sell", "size" => 1501, "symbol" => "XBTUSD"}]}}, 1_000
    #        assert_receive {{:data, "orderBookL2", "XBTUSD"}, %{insert: [%{"id" => 8790000000, "price" => 100000, "side" => "Sell", "size" => 1501, "symbol" => "XBTUSD"}]}}, 1_000
    #      end)
    #
    #      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
    #      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})
    #      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
    #      TestServer.send_message(server, %{"error" => "You are already subscribed to this topic: orderBookL2:XBTUSD", "meta" => %{}, "request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "status" => 400})
    #      TestServer.send_message(server, %{"action" => "partial", "attributes" => %{"id" => "sorted", "symbol" => "grouped"}, "data" => [%{"id" => 8790000000, "price" => 100000, "side" => "Sell", "size" => 1501, "symbol" => "XBTUSD"}], "filter" => %{"symbol" => "XBTUSD"}, "foreignKeys" => %{"side" => "side", "symbol" => "instrument"}, "keys" => ["symbol", "id", "side"], "table" => "orderBookL2", "types" => %{"id" => "long", "price" => "float", "side" => "symbol", "size" => "long", "symbol" => "symbol"}})
    #      Task.await(task)
    #    end

    test "can receive messages after subscribtion (`insert` event)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orderbook(client, "XBT", "USD")

          Process.sleep(100)
          assert_receive {{:data, "orderBookL2", "XBTUSD"}, %{insert: [%{"id" => 8_799_295_060, "price" => 7049.4, "side" => "Sell", "size" => 15000, "symbol" => "XBTUSD"}]}}, 1_000
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})
      Process.sleep(100)
      TestServer.send_message(server, %{"action" => "insert", "data" => [%{"id" => 8_799_295_060, "price" => 7049.4, "side" => "Sell", "size" => 15000, "symbol" => "XBTUSD"}], "table" => "orderBookL2"})
      Task.await(task)
    end

    test "can receive messages after subscribtion (`update` event)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orderbook(client, "XBT", "USD")

          Process.sleep(100)
          assert_receive {{:data, "orderBookL2", "XBTUSD"}, %{update: [%{"id" => 8_799_295_060, "side" => "Sell", "size" => 30000, "symbol" => "XBTUSD"}]}}, 1_000
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})
      Process.sleep(100)
      TestServer.send_message(server, %{"action" => "update", "data" => [%{"id" => 8_799_295_060, "side" => "Sell", "size" => 30000, "symbol" => "XBTUSD"}], "table" => "orderBookL2"})
      Task.await(task)
    end

    test "can receive messages after subscribtion (`delete` event)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orderbook(client, "XBT", "USD")

          Process.sleep(100)
          assert_receive {{:data, "orderBookL2", "XBTUSD"}, %{delete: [%{"id" => 8_799_296_060, "side" => "Buy", "symbol" => "XBTUSD"}]}}, 1_000
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["orderBookL2:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["orderBookL2:XBTUSD"], "op" => "subscribe"}, "subscribe" => "orderBookL2:XBTUSD", "success" => true})
      Process.sleep(100)
      TestServer.send_message(server, %{"action" => "delete", "data" => [%{"id" => 8_799_296_060, "side" => "Buy", "symbol" => "XBTUSD"}], "table" => "orderBookL2"})
      Task.await(task)
    end
  end

  describe "Request/Orders" do
    setup do
      init()
    end

    test "can subscribe on orders (success)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_orders(client, "XBT", "USD")
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["order:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["order:XBTUSD"], "op" => "subscribe"}, "subscribe" => "order:XBTUSD", "success" => true})

      success(_) = Task.await(task)
    end

    test "can receive messages after subscribtion (initial `partial` message)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_orders(client, "XBT", "USD")

          assert_receive {{:data, "order", "XBTUSD"},
                          %{
                            insert: [
                              %{
                                "side" => "Buy",
                                "transactTime" => "2017-11-03T08:30:31.472Z",
                                "ordType" => "Limit",
                                "displayQty" => nil,
                                "stopPx" => nil,
                                "settlCurrency" => "XBt",
                                "triggered" => "",
                                "orderID" => "d2bb2227-ed33-ff44-a63b-aad22316a52e",
                                "currency" => "USD",
                                "pegOffsetValue" => nil,
                                "price" => 5000,
                                "pegPriceType" => "",
                                "text" => "Submission from www.bitmex.com",
                                "workingIndicator" => true,
                                "multiLegReportingType" => "SingleSecurity",
                                "timestamp" => "2017-11-03T08:30:31.472Z",
                                "cumQty" => 0,
                                "ordRejReason" => "",
                                "avgPx" => nil,
                                "orderQty" => 1,
                                "simpleOrderQty" => nil,
                                "ordStatus" => "New",
                                "timeInForce" => "GoodTillCancel",
                                "clOrdLinkID" => "",
                                "simpleLeavesQty" => 0.0002,
                                "leavesQty" => 1,
                                "exDestination" => "XBME",
                                "symbol" => "XBTUSD",
                                "account" => 90042,
                                "clOrdID" => "",
                                "simpleCumQty" => 0,
                                "execInst" => "ParticipateDoNotInitiate",
                                "contingencyType" => ""
                              }
                            ]
                          }},
                         1_000
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["order:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["order:XBTUSD"], "op" => "subscribe"}, "subscribe" => "order:XBTUSD", "success" => true})
      TestServer.send_message(server, %{"action" => "partial", "attributes" => %{"account" => "grouped", "ordStatus" => "grouped", "orderID" => "grouped", "workingIndicator" => "grouped"}, "data" => [%{"side" => "Buy", "transactTime" => "2017-11-03T08:30:31.472Z", "ordType" => "Limit", "displayQty" => nil, "stopPx" => nil, "settlCurrency" => "XBt", "triggered" => "", "orderID" => "d2bb2227-ed33-ff44-a63b-aad22316a52e", "currency" => "USD", "pegOffsetValue" => nil, "price" => 5000, "pegPriceType" => "", "text" => "Submission from www.bitmex.com", "workingIndicator" => true, "multiLegReportingType" => "SingleSecurity", "timestamp" => "2017-11-03T08:30:31.472Z", "cumQty" => 0, "ordRejReason" => "", "avgPx" => nil, "orderQty" => 1, "simpleOrderQty" => nil, "ordStatus" => "New", "timeInForce" => "GoodTillCancel", "clOrdLinkID" => "", "simpleLeavesQty" => 0.0002, "leavesQty" => 1, "exDestination" => "XBME", "symbol" => "XBTUSD", "account" => 90042, "clOrdID" => "", "simpleCumQty" => 0, "execInst" => "ParticipateDoNotInitiate", "contingencyType" => ""}], "filter" => %{"account" => 90042, "symbol" => "XBTUSD"}, "foreignKeys" => %{"ordStatus" => "ordStatus", "side" => "side", "symbol" => "instrument"}, "keys" => ["orderID"], "table" => "order", "types" => %{"side" => "symbol", "transactTime" => "timestamp", "ordType" => "symbol", "displayQty" => "long", "stopPx" => "float", "settlCurrency" => "symbol", "triggered" => "symbol", "orderID" => "guid", "currency" => "symbol", "pegOffsetValue" => "float", "price" => "float", "pegPriceType" => "symbol", "text" => "symbol", "workingIndicator" => "boolean", "multiLegReportingType" => "symbol", "timestamp" => "timestamp", "cumQty" => "long", "ordRejReason" => "symbol", "avgPx" => "float", "orderQty" => "long", "simpleOrderQty" => "float", "ordStatus" => "symbol", "timeInForce" => "symbol", "clOrdLinkID" => "symbol", "simpleLeavesQty" => "float", "leavesQty" => "long", "exDestination" => "symbol", "symbol" => "symbol", "account" => "long", "clOrdID" => "symbol", "simpleCumQty" => "float", "execInst" => "symbol", "contingencyType" => "symbol"}})
      Task.await(task)
    end
  end

  describe "Request/Positions" do
    setup do
      init()
    end

    test "can subscribe on positions (success)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_positions(client, "XBT", "USD")
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["position:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["position:XBTUSD"], "op" => "subscribe"}, "subscribe" => "position:XBTUSD", "success" => true})

      success(_) = Task.await(task)
    end

    test "can receive messages after subscribtion (initial `partial` message)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_positions(client, "XBT", "USD")

          assert_receive {{:data, "position", "XBTUSD"},
                          %{
                            insert: [
                              %{
                                "avgCostPrice" => 7439.9,
                                "grossOpenCost" => 0,
                                "posCross" => 27,
                                "unrealisedCost" => -13441,
                                "marginCallPrice" => 216.1,
                                "currentTimestamp" => "2017-11-03T08:58:40.154Z",
                                "markValue" => -13468,
                                "simpleCost" => 1,
                                "openingComm" => 0,
                                "execQty" => 1,
                                "unrealisedPnlPcnt" => -0.002,
                                "realisedPnl" => -9,
                                "liquidationPrice" => 216.1,
                                "deleveragePercentile" => 1,
                                "rebalancedPnl" => 0,
                                "varMargin" => 0,
                                "openingTimestamp" => "2017-11-03T08:00:00.000Z",
                                "execSellQty" => 0,
                                "openOrderSellCost" => 0,
                                "initMarginReq" => 0.01,
                                "realisedCost" => 0,
                                "isOpen" => true,
                                "posAllowance" => 0,
                                "unrealisedGrossPnl" => -27,
                                "breakEvenPrice" => 7445,
                                "currency" => "XBt",
                                "quoteCurrency" => "USD",
                                "longBankrupt" => 0,
                                "homeNotional" => 1.3468e-4,
                                "openOrderSellPremium" => 0,
                                "realisedGrossPnl" => 0,
                                "lastValue" => -13468,
                                "currentComm" => 9,
                                "openOrderBuyPremium" => 0,
                                "underlying" => "XBT",
                                "simpleValue" => 1,
                                "markPrice" => 7424.96,
                                "timestamp" => "2017-11-03T08:58:40.154Z",
                                "taxableMargin" => 0,
                                "taxBase" => 0,
                                "crossMargin" => true,
                                "execCost" => -13441,
                                "openingCost" => 0,
                                "simplePnl" => 0,
                                "avgEntryPrice" => 7439.9,
                                "initMargin" => 0,
                                "posState" => ""
                                # ...
                              }
                            ]
                          }},
                         1_000
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["position:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["position:XBTUSD"], "op" => "subscribe"}, "subscribe" => "position:XBTUSD", "success" => true})
      TestServer.send_message(server, %{"action" => "partial", "attributes" => %{"account" => "sorted", "currency" => "grouped", "quoteCurrency" => "grouped", "symbol" => "grouped", "underlying" => "grouped"}, "data" => [%{"avgCostPrice" => 7439.9, "grossOpenCost" => 0, "posCross" => 27, "unrealisedCost" => -13441, "marginCallPrice" => 216.1, "currentTimestamp" => "2017-11-03T08:58:40.154Z", "markValue" => -13468, "simpleCost" => 1, "openingComm" => 0, "execQty" => 1, "unrealisedPnlPcnt" => -0.002, "realisedPnl" => -9, "liquidationPrice" => 216.1, "deleveragePercentile" => 1, "rebalancedPnl" => 0, "varMargin" => 0, "openingTimestamp" => "2017-11-03T08:00:00.000Z", "execSellQty" => 0, "openOrderSellCost" => 0, "initMarginReq" => 0.01, "realisedCost" => 0, "isOpen" => true, "posAllowance" => 0, "unrealisedGrossPnl" => -27, "breakEvenPrice" => 7445, "currency" => "XBt", "quoteCurrency" => "USD", "longBankrupt" => 0, "homeNotional" => 1.3468e-4, "openOrderSellPremium" => 0, "realisedGrossPnl" => 0, "lastValue" => -13468, "currentComm" => 9, "openOrderBuyPremium" => 0, "underlying" => "XBT", "simpleValue" => 1, "markPrice" => 7424.96, "timestamp" => "2017-11-03T08:58:40.154Z", "taxableMargin" => 0, "taxBase" => 0, "crossMargin" => true, "execCost" => -13441, "openingCost" => 0, "simplePnl" => 0, "avgEntryPrice" => 7439.9, "initMargin" => 0, "posState" => ""}], "filter" => %{"account" => 90042, "symbol" => "XBTUSD"}, "foreignKeys" => %{"symbol" => "instrument"}, "keys" => ["account", "symbol", "currency"], "table" => "position", "types" => %{"avgCostPrice" => "float", "grossOpenCost" => "long", "posCross" => "long", "unrealisedCost" => "long", "marginCallPrice" => "float", "currentTimestamp" => "timestamp", "markValue" => "long", "simpleCost" => "float", "openingComm" => "long", "execQty" => "long", "unrealisedPnlPcnt" => "float", "realisedPnl" => "long", "liquidationPrice" => "float", "deleveragePercentile" => "float", "rebalancedPnl" => "long", "varMargin" => "long", "openingTimestamp" => "timestamp", "execSellQty" => "long", "openOrderSellCost" => "long", "initMarginReq" => "float", "realisedCost" => "long", "isOpen" => "boolean", "posAllowance" => "long", "unrealisedGrossPnl" => "long", "breakEvenPrice" => "float", "currency" => "symbol", "quoteCurrency" => "symbol", "longBankrupt" => "long", "homeNotional" => "float", "openOrderSellPremium" => "long", "realisedGrossPnl" => "long", "lastValue" => "long", "currentComm" => "long", "openOrderBuyPremium" => "long", "underlying" => "symbol", "simpleValue" => "float", "markPrice" => "float", "timestamp" => "timestamp", "taxableMargin" => "long", "taxBase" => "long", "crossMargin" => "boolean", "execCost" => "long", "openingCost" => "long"}})
      Task.await(task)
    end
  end

  describe "Request/Trades" do
    setup do
      init()
    end

    test "can subscribe on trades (success)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          Websocket.subscribe_trades(client, "XBT", "USD")
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["trade:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["trade:XBTUSD"], "op" => "subscribe"}, "subscribe" => "trade:XBTUSD", "success" => true})

      success(_) = Task.await(task)
    end

    test "can receive messages after subscribtion (initial `partial` message)", %{client: client, server: server} do
      task =
        Task.async(fn ->
          success(_) = Websocket.subscribe_trades(client, "XBT", "USD")

          assert_receive {{:data, "trade", "XBTUSD"}, %{initial: true, insert: [%{"foreignNotional" => 82, "grossValue" => 936_358, "homeNotional" => 0.00936358, "price" => 8757.50000000, "side" => "Sell", "size" => 82, "symbol" => "XBTUSD", "tickDirection" => "MinusTick", "timestamp" => "2018-02-12T13:33:46.960Z", "trdMatchID" => "11ffd9e1-8271-e824-ae4a-8f228d0979b1"}]}}
        end)

      TestServer.expect_message(server, %{op: "subscribe", args: ["trade:XBTUSD"]})
      TestServer.send_message(server, %{"request" => %{"args" => ["trade:XBTUSD"], "op" => "subscribe"}, "subscribe" => "trade:XBTUSD", "success" => true})
      TestServer.send_message(server, %{"action" => "partial", "attributes" => %{"symbol" => "grouped", "timestamp" => "sorted"}, "data" => [%{"foreignNotional" => 82, "grossValue" => 936_358, "homeNotional" => 0.00936358, "price" => 8757.50000000, "side" => "Sell", "size" => 82, "symbol" => "XBTUSD", "tickDirection" => "MinusTick", "timestamp" => "2018-02-12T13:33:46.960Z", "trdMatchID" => "11ffd9e1-8271-e824-ae4a-8f228d0979b1"}], "filter" => %{"symbol" => "XBTUSD"}, "foreignKeys" => %{"side" => "side", "symbol" => "instrument"}, "keys" => [], "table" => "trade", "types" => %{"foreignNotional" => "float", "grossValue" => "long", "homeNotional" => "float", "price" => "float", "side" => "symbol", "size" => "long", "symbol" => "symbol", "tickDirection" => "symbol", "timestamp" => "timestamp", "trdMatchID" => "guid"}})
      Task.await(task)
    end
  end
end
