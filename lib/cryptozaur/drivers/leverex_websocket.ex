defmodule Cryptozaur.Drivers.LeverexWebsocket do
  use WebSockex

  @protocol "wss"
  @host "https://moonbase.exchange"
  @api_key "your_api_key"
  @secret "your_secret"

  def start_link do
    WebSockex.start_link(url(), __MODULE__, %{ref: 1}, name: __MODULE__)
  end

  def join_balances do
    ref = get_main_ref()
    set_channel_info(:balances, ref, [])
    send_frame(frame(ref, ref, "/balances/", "phx_join", %{}))
  end

  def join_orderbooks(symbol, opts \\ []) do
    ref = get_main_ref()
    set_channel_info(:orderbooks, ref, [symbol, opts])
    send_frame(frame(ref, ref, "/orderbooks/#{symbol}", "phx_join", Map.new(opts)))
  end

  def join_orders(symbol, opts \\ []) do
    ref = get_main_ref()
    set_channel_info(:orders, ref, [symbol, opts])
    send_frame(frame(ref, ref, "/orders/#{symbol}", "phx_join", Map.new(opts)))
  end

  def place_order(symbol, opts) do
    ref = get_main_ref()
    join_ref = get_join_ref(:orders)
    send_frame(frame(ref, join_ref, "/orders/#{symbol}", "place", Map.new(opts)))
  end

  def cancel_order(symbol, opts) do
    ref = get_main_ref()
    join_ref = get_join_ref(:orders)
    send_frame(frame(ref, join_ref, "/orders/#{symbol}", "cancel", Map.new(opts)))
  end

  def join_positions do
    ref = get_main_ref()
    set_channel_info(:positions, ref, [])
    send_frame(frame(ref, ref, "/positions/", "phx_join", %{}))
  end

  def assign_position(opts) do
    ref = get_main_ref()
    join_ref = get_join_ref(:positions)
    send_frame(frame(ref, join_ref, "/positions/", "assign", Map.new(opts)))
  end

  def join_tickers(opts \\ []) do
    ref = get_main_ref()
    set_channel_info(:tickers, ref, [opts])
    send_frame(frame(ref, ref, "/tickers", "phx_join", Map.new(opts)))
  end

  def join_trades(symbol) do
    ref = get_main_ref()
    set_channel_info(:trades, ref, [symbol])
    send_frame(frame(ref, ref, "/trades/#{symbol}", "phx_join", %{}))
  end

  def join_candles(symbol, opts) do
    ref = get_main_ref()
    set_channel_info(:candles, ref, [symbol, opts])
    send_frame(frame(ref, ref, "/candles/#{symbol}", "phx_join", Map.new(opts)))
  end

  def get_snapshot(symbol, opts) do
    ref = get_main_ref()
    join_ref = get_join_ref(:candles)
    send_frame(frame(ref, join_ref, "/candles/#{symbol}", "get_snapshot", Map.new(opts)))
  end

  def join_deposits(opts \\ []) do
    ref = get_main_ref()
    set_channel_info(:deposits, ref, [opts])
    send_frame(frame(ref, ref, "/deposits/", "phx_join", Map.new(opts)))
  end

  def get_deposit_address(opts \\ []) do
    ref = get_main_ref()
    join_ref = get_join_ref(:deposits)
    send_frame(frame(ref, join_ref, "/deposits/", "get_deposit_address", Map.new(opts)))
  end

  def join_withdrawals(opts \\ []) do
    ref = get_main_ref()
    set_channel_info(:withdrawals, ref, [opts])
    send_frame(frame(1, 1, "/withdrawals/", "phx_join", Map.new(opts)))
  end

  def create_withdrawal(opts) do
    ref = get_main_ref()
    join_ref = get_join_ref(:withdrawals)
    send_frame(frame(ref, join_ref, "/withdrawals/", "create_withdrawal", Map.new(opts)))
  end

  def send_frame(frame) do
    WebSockex.send_frame(__MODULE__, {:text, frame})
  end

  def handle_info({:"$gen_cast", :increment_ref}, %{counter: counter}) do
    {:ok, %{counter: counter + 1}}
  end

  def handle_connect(_conn, state) do
    IO.puts("Connected")
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    IO.inspect(msg)
    {:ok, state}
  end

  def handle_disconnect(_connection_status_map, state) do
    IO.puts("Reconnecting...")
    {:reconnect, state}
  end

  def terminate(reason, state) do
    IO.puts("\nSocket Terminating:\n#{inspect(reason)}\n\n#{inspect(state)}\n")
    exit(:normal)
  end

  def url do
    "#{@protocol}://#{@host}/socket/api/websocket?#{auth_query_string()}"
  end

  def auth_query_string do
    params = %{key: @api_key, timestamp: :os.system_time(:second)}
    %{"auth_signature" => signature} = Signaturex.sign(@api_key, @secret, :get, "/users/verify", params)
    params = Map.put(params, "signature", signature)
    URI.encode_query(params)
  end

  def frame(ref, join_ref, topic, event, payload) do
    %{ref: to_string(ref), join_ref: to_string(join_ref), topic: topic, event: event, payload: payload} |> Poison.encode!()
  end

  def get_join_ref(ref_name \\ :ref) do
    :sys.get_state(__MODULE__) |> Map.get(ref_name) |> Map.get(:join_ref)
  end

  def get_main_ref do
    :sys.get_state(__MODULE__) |> Map.get(:ref)
  end

  def incr_ref do
    :sys.replace_state(__MODULE__, &Map.update!(&1, :counter, fn x -> x + 1 end))
  end

  def set_channel_info(channel, join_ref, opts) do
    :sys.replace_state(__MODULE__, &Map.put(&1, channel, %{join_ref: join_ref, opts: opts}))
  end
end
