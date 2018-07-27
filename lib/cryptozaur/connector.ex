defmodule Cryptozaur.Connector do
  import Cryptozaur.Utils
  import OK, only: [success: 1, failure: 1]

  @exchanges [
    %{slug: "MTGOX", name: "MtGox", connector: Elixir.Cryptozaur.Connectors.Mtgox, maker_fee: 0.0025, taker_fee: 0.0040, is_public: false},
    %{slug: "LEVEREX", name: "LeverEX", connector: Elixir.Cryptozaur.Connectors.Leverex, maker_fee: 0.0010, taker_fee: 0.0010, is_public: true},
    %{slug: "BITTREX", name: "Bittrex", connector: Elixir.Cryptozaur.Connectors.Bittrex, maker_fee: 0.0025, taker_fee: 0.0025, is_public: true},
    %{slug: "BINANCE", name: "Binance", connector: Elixir.Cryptozaur.Connectors.Binance, maker_fee: 0.0010, taker_fee: 0.0010, is_public: true},
    %{slug: "BITMEX", name: "Bitmex", connector: Elixir.Cryptozaur.Connectors.Bitmex, maker_fee: -0.00025, taker_fee: 0.00075, is_public: false},
    %{slug: "BITFINEX", name: "Bitfinex", connector: Elixir.Cryptozaur.Connectors.Bitfinex, maker_fee: 0.0010, taker_fee: 0.0020, is_public: true},
    %{slug: "GATE", name: "Gate", connector: Elixir.Cryptozaur.Connectors.Gate, maker_fee: 0.0025, taker_fee: 0.0025, is_public: true},
    %{slug: "POLONIEX", name: "Poloniex", connector: Elixir.Cryptozaur.Connectors.Poloniex, maker_fee: 0.0015, taker_fee: 0.0025, is_public: false},
    %{slug: "YOBIT", name: "Yobit", connector: Elixir.Cryptozaur.Connectors.Yobit, maker_fee: 0.0020, taker_fee: 0.0020, is_public: false},
    %{slug: "KUCOIN", name: "Kucoin", connector: Elixir.Cryptozaur.Connectors.Kucoin, maker_fee: 0.0010, taker_fee: 0.0010, is_public: true},
    %{slug: "HUOBI", name: "Huobi", connector: Elixir.Cryptozaur.Connectors.Huobi, maker_fee: 0.0020, taker_fee: 0.0020, is_public: true},
    %{slug: "HITBTC", name: "HitBTC", connector: Elixir.Cryptozaur.Connectors.Hitbtc, maker_fee: -0.0001, taker_fee: 0.0010, is_public: false},
    %{slug: "BITHUMB", name: "Bithumb", connector: Elixir.Cryptozaur.Connectors.Bithumb, maker_fee: 0.0015, taker_fee: 0.0015, is_public: true},
    %{slug: "CRYPTOCOMPARE", name: "CryptoCompare", connector: Cryptozaur.Connectors.CryptoCompare, maker_fee: 0.0000, taker_fee: 0.0000, is_public: false},
    # TODO: OKEx fees are different for different pairs
    # TODO: OKEx fees are different for futures / spot
    %{slug: "OKEX", name: "OKEx", connector: Elixir.Cryptozaur.Connectors.Okex, maker_fee: -0.0010, taker_fee: 0.0010, is_public: true}
  ]

  defmacrop execute(exchange, method, args) do
    quote do
      with success(module) <- get_exchange_by_slug(unquote(exchange)), do: apply(module.connector, unquote(method), unquote(args))
    end
  end

  defmacrop execute(exchange, method, args, fallback) do
    quote do
      with success(module) <- get_exchange_by_slug(unquote(exchange)) do
        apply(module.connector, unquote(method), unquote(args))
      else
        err -> if unquote(fallback), do: unquote(fallback), else: err
      end
    end
  end

  def credentials_valid?(exchange, key, secret) do
    if is_supported(exchange, :credentials_valid?, 2) do
      execute(exchange, :credentials_valid?, [key, secret])
    else
      case get_balances(exchange, key, secret) do
        success(_) -> success(true)
        failure(message) -> failure(message)
      end
    end
  end

  def pair_valid?(exchange, base, quote) do
    if is_supported(exchange, :pair_valid?, 2) do
      execute(exchange, :pair_valid?, [base, quote])
    else
      case get_ticker(exchange, base, quote) do
        success(nil) -> success(false)
        success(_) -> success(true)
        failure(message) -> failure(message)
      end
    end
  end

  def get_info(exchange, extra \\ []) do
    execute(exchange, :get_info, [extra])
  end

  def get_symbols(exchange) do
    if is_supported(exchange, :get_symbols, 0) do
      execute(exchange, :get_symbols, [])
    else
      with success(tickers) <- execute(exchange, :get_tickers, []) do
        tickers |> pluck(:symbol) |> success()
      end
    end
  end

  # some exchanges allow to request just a single ticker
  def get_ticker(exchange, base, quote) do
    if is_supported(exchange, :get_ticker, 2) do
      execute(exchange, :get_ticker, [base, quote])
    else
      symbol = "#{exchange}:#{base}:#{quote}"

      with success(tickers) <- execute(exchange, :get_tickers, []) do
        tickers |> Enum.find(&(&1.symbol == symbol)) |> success()
      end
    end
  end

  def get_tickers(exchange) do
    execute(exchange, :get_tickers, [])
  end

  def get_torches(exchange, base, quote, from, to, resolution, limit \\ 0) do
    if is_supported(exchange, :get_torches, 6) do
      execute(exchange, :get_torches, [base, quote, from, to, resolution, limit])
    else
      # TODO: implement support for `from` argument in CryptoCompare.get_torches function
      # Cryptozaur.Connectors.CryptoCompare.get_torches(exchange, base, quote, resolution, from, to, limit)
    end
  end

  def iterate_torches(exchange, base, quote, from, to, resolution, callback) do
    execute(exchange, :iterate_torches, [base, quote, from, to, resolution, callback])
  end

  def get_levels(exchange, base, quote, limit \\ 0) do
    execute(exchange, :get_levels, [base, quote, limit])
  end

  def get_summaries(exchange) do
    execute(exchange, :get_summaries, [])
  end

  def get_candles(exchange, base, quote, resolution) do
    execute(exchange, :get_candles, [base, quote, resolution])
  end

  def get_latest_trades(exchange, base, quote) do
    execute(exchange, :get_latest_trades, [base, quote])
  end

  def get_latest_trades!(exchange, base, quote) do
    bangify(get_latest_trades(exchange, base, quote))
  end

  def get_trades(exchange, base, quote, from, to, extra \\ []) do
    execute(exchange, :get_trades, [base, quote, from, to, extra])
  end

  def iterate_trades(exchange, base, quote, from, to, callback) do
    execute(exchange, :iterate_trades, [base, quote, from, to, callback])
  end

  def get_depth(exchange, base, quote) do
    execute(exchange, :get_depth, [base, quote])
  end

  def get_balances(exchange, key, secret) do
    execute(exchange, :get_balances, [key, secret])
  end

  # TODO: temp; remove it after Balance model has amount_total, amount_available, amount_pending
  def get_balances_as_maps(exchange, key, secret) do
    execute(exchange, :get_balances_as_maps, [key, secret])
  end

  def get_balance(exchange, key, secret, currency) do
    if is_supported(exchange, :get_balance, 3) do
      execute(exchange, :get_balance, [key, secret, currency])
    else
      with success(balances) <- execute(exchange, :get_balances, [key, secret]) do
        balances |> Enum.find(&(&1.currency == currency)) |> success()
      end
    end
  end

  def withdraw(exchange, key, secret, currency, amount, address) do
    execute(exchange, :withdraw, [key, secret, currency, amount, address])
  end

  def get_deposit_address(exchange, key, secret, currency) do
    execute(exchange, :get_deposit_address, [key, secret, currency])
  end

  def place_order(exchange, key, secret, base, quote, amount, price, extra \\ []) do
    execute(exchange, :place_order, [key, secret, base, quote, amount, price, extra])
  end

  def change_order(exchange, key, secret, base, quote, uid, amount, price, extra \\ []) do
    execute(exchange, :change_order, [key, secret, base, quote, uid, amount, price, extra])
  end

  def validate_order(exchange, base, quote, amount, price) do
    execute(exchange, :validate_order, [base, quote, amount, price])
  end

  def subscribe_ticker(exchange, base, quote) do
    execute(exchange, :subscribe_ticker, [base, quote])
  end

  def subscribe_trades(exchange, base, quote) do
    execute(exchange, :subscribe_trades, [base, quote])
  end

  def subscribe_levels(exchange, base, quote) do
    execute(exchange, :subscribe_levels, [base, quote])
  end

  def subscribe_orders(exchange, base, quote, key, secret) do
    execute(exchange, :subscribe_orders, [base, quote, key, secret])
  end

  def subscribe_positions(exchange, base, quote, key, secret) do
    execute(exchange, :subscribe_positions, [base, quote, key, secret])
  end

  def get_min_price(exchange, base, quote) do
    execute(exchange, :get_min_price, [base, quote])
  end

  def get_max_price(_exchange, _base, quote) do
    # temporary
    case quote do
      "BTC" -> 1.0
      "ETH" -> 10.0
      "USD" -> 10000.0
      "USDT" -> 10000.0
    end
  end

  def get_min_amount(exchange, base, price) do
    execute(exchange, :get_min_amount, [base, price])
  end

  def get_amount_precision(exchange, base, quote) do
    execute(exchange, :get_amount_precision, [base, quote], get_fallback_amount_precision(exchange, base, quote))
  end

  def get_price_precision(exchange, base, quote) do
    execute(exchange, :get_price_precision, [base, quote], get_fallback_price_precision(exchange, base, quote))
  end

  def get_tick(exchange, base, quote) do
    execute(exchange, :get_tick, [base, quote])
  end

  # Binance requires to pass the base-quote pair along with uid
  def cancel_order(exchange, key, secret, base, quote, uid) do
    execute(exchange, :cancel_order, [key, secret, base, quote, uid])
  end

  # Kucoin requires to pass the base-quote pair, uid and the type
  def cancel_order(exchange, key, secret, base, quote, uid, type) do
    execute(exchange, :cancel_order, [key, secret, base, quote, uid, type])
  end

  def get_orders(exchange, key, secret) do
    execute(exchange, :get_orders, [key, secret])
  end

  def get_orders(exchange, key, secret, base, quote) do
    execute(exchange, :get_orders, [key, secret, base, quote])
  end

  def get_link(exchange, base, quote) do
    execute(exchange, :get_link, [base, quote], "")
  end

  def get_fee(exchange, base, quote, type) when type in [:taker, :maker] do
    if is_supported(exchange, :get_fee, 3) do
      execute(exchange, :get_fee, [base, quote, type])
    else
      success(data) = get_exchange_by_slug(exchange)
      if type == :maker, do: data.maker_fee, else: data.taker_fee
    end
  end

  def is_supported(exchange, function, arity) do
    OK.try do
      module <- get_exchange_by_slug(exchange)
    after
      Code.ensure_loaded(module.connector)
      function_exported?(module.connector, function, arity)
    rescue
      _e -> false
    end
  end

  def get_exchange_by_slug(slug) do
    case Enum.find(@exchanges, &(&1.slug == slug)) do
      nil -> failure("Exchange #{slug} is not supported")
      data -> success(data)
    end
  end

  def get_exchange_by_name(name) do
    case Enum.find(@exchanges, &(&1.name == name)) do
      nil -> failure("Exchange #{name} is not supported")
      data -> success(data)
    end
  end

  def get_public_exchanges() do
    @exchanges |> Enum.filter(&(&1.is_public == true))
  end

  def get_exchanges() do
    @exchanges
  end

  defp get_fallback_amount_precision(_exchange, _base, _quote) do
    8
  end

  defp get_fallback_price_precision(_exchange, _base, quote) do
    case quote do
      "BTC" -> 8
      "ETH" -> 8
      "USD" -> 1
      "USDT" -> 1
    end
  end
end
