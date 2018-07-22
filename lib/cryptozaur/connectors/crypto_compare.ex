defmodule Cryptozaur.Connectors.CryptoCompare do
  require OK
  import OK, only: [success: 1, failure: 1]
  import Cryptozaur.Utils
  import Cryptozaur.Logger
  alias Cryptozaur.Model.{Ticker, Torch}
  alias Cryptozaur.Drivers.CryptoCompareRest, as: Rest

  @actual_limit 2000
#  @minute_candle_limit 1440
  # Update @exchanges: mix run -e 'Cryptozaur.Connectors.CryptoCompare.get_exchanges() |> elem(1) |> IO.inspect(limit: :infinity)'
  @exchanges [
    %{name: "BitMarket", slug: "BITMARKET"},
    %{name: "BTCXIndia", slug: "BTCXINDIA"},
    %{name: "CoinDeal", slug: "COINDEAL"},
    %{name: "LakeBTC", slug: "LAKEBTC"},
    %{name: "LAToken", slug: "LATOKEN"},
    %{name: "CCEX", slug: "CCEX"},
    %{name: "SingularityX", slug: "SINGULARITYX"},
    %{name: "bitFlyer", slug: "BITFLYER"},
    %{name: "IDEX", slug: "IDEX"},
    %{name: "BitFlip", slug: "BITFLIP"},
    %{name: "Graviex", slug: "GRAVIEX"},
    %{name: "Unocoin", slug: "UNOCOIN"},
    %{name: "Coinse", slug: "COINSE"},
    %{name: "Yobit", slug: "YOBIT"},
    %{name: "Cexio", slug: "CEXIO"},
    %{name: "Quoine", slug: "QUOINE"},
    %{name: "BTCMarkets", slug: "BTCMARKETS"},
    %{name: "Kucoin", slug: "KUCOIN"},
    %{name: "LiveCoin", slug: "LIVECOIN"},
    %{name: "Buda", slug: "BUDA"},
    %{name: "Neraex", slug: "NERAEX"},
    %{name: "Yacuna", slug: "YACUNA"},
    %{name: "Coinbase", slug: "COINBASE"},
    %{name: "Bitmex", slug: "BITMEX"},
    %{name: "Bitfinex", slug: "BITFINEX"},
    %{name: "Coinone", slug: "COINONE"},
    %{name: "Vaultoro", slug: "VAULTORO"},
    %{name: "Binance", slug: "BINANCE"},
    %{name: "BitGrail", slug: "BITGRAIL"},
    %{name: "QuadrigaCX", slug: "QUADRIGACX"},
    %{name: "TradeSatoshi", slug: "TRADESATOSHI"},
    %{name: "MonetaGo", slug: "MONETAGO"},
    %{name: "AidosMarket", slug: "AIDOSMARKET"},
    %{name: "Korbit", slug: "KORBIT"},
    %{name: "Velox", slug: "VELOX"},
    %{name: "Bitlish", slug: "BITLISH"},
    %{name: "Nebula", slug: "NEBULA"},
    %{name: "BitZ", slug: "BITZ"},
    %{name: "Surbitcoin", slug: "SURBITCOIN"},
    %{name: "itBit", slug: "ITBIT"},
    %{name: "Coinsetter", slug: "COINSETTER"},
    %{name: "BTCTurk", slug: "BTCTURK"},
    %{name: "Bleutrade", slug: "BLEUTRADE"},
    %{name: "Coinfloor", slug: "COINFLOOR"},
    %{name: "TheRockTrading", slug: "THEROCKTRADING"},
    %{name: "EXX", slug: "EXX"},
    %{name: "ViaBTC", slug: "VIABTC"},
    %{name: "Coincheck", slug: "COINCHECK"},
    %{name: "Simex", slug: "SIMEX"},
    %{name: "Coinroom", slug: "COINROOM"},
    %{name: "OKCoin", slug: "OKCOIN"},
    %{name: "Tidex", slug: "TIDEX"},
    %{name: "CHBTC", slug: "CHBTC"},
    %{name: "OKEX", slug: "OKEX"},
    %{name: "EthexIndia", slug: "ETHEXINDIA"},
    %{name: "TrustDEX", slug: "TRUSTDEX"},
    %{name: "EtherDelta", slug: "ETHERDELTA"},
    %{name: "ChileBit", slug: "CHILEBIT"},
    %{name: "TokenStore", slug: "TOKENSTORE"},
    %{name: "BXinth", slug: "BXINTH"},
    %{name: "Braziliex", slug: "BRAZILIEX"},
    %{name: "VBTC", slug: "VBTC"},
    %{name: "BitTrex", slug: "BITTREX"},
    %{name: "Novaexchange", slug: "NOVAEXCHANGE"},
    %{name: "BitBay", slug: "BITBAY"},
    %{name: "Upbit", slug: "UPBIT"},
    %{name: "BitSquare", slug: "BITSQUARE"},
    %{name: "HuobiPro", slug: "HUOBIPRO"},
    %{name: "Bibox", slug: "BIBOX"},
    %{name: "Bitso", slug: "BITSO"},
    %{name: "Gemini", slug: "GEMINI"},
    %{name: "MercadoBitcoin", slug: "MERCADOBITCOIN"},
    %{name: "CryptoX", slug: "CRYPTOX"},
    %{name: "Gateio", slug: "GATEIO"},
    %{name: "btcXchange", slug: "BTCXCHANGE"},
    %{name: "BTC38", slug: "BTC38"},
    %{name: "Poloniex", slug: "POLONIEX"},
    %{name: "CoinEx", slug: "COINEX"},
    %{name: "Abucoins", slug: "ABUCOINS"},
    %{name: "WavesDEX", slug: "WAVESDEX"},
    %{name: "RightBTC", slug: "RIGHTBTC"},
    %{name: "ZB", slug: "ZB"},
    %{name: "CoinCorner", slug: "COINCORNER"},
    %{name: "Liqui", slug: "LIQUI"},
    %{name: "Bithumb", slug: "BITHUMB"},
    %{name: "BTCChina", slug: "BTCCHINA"},
    %{name: "Cryptopia", slug: "CRYPTOPIA"},
    %{name: "Yunbi", slug: "YUNBI"},
    %{name: "Ethfinex", slug: "ETHFINEX"},
    %{name: "Bitstamp", slug: "BITSTAMP"},
    %{name: "DDEX", slug: "DDEX"},
    %{name: "CCEDK", slug: "CCEDK"},
    %{name: "Paymium", slug: "PAYMIUM"},
    %{name: "Kraken", slug: "KRAKEN"},
    %{name: "CCCAGG", slug: "CRYPTOCOMPARE"},
    %{name: "Remitano", slug: "REMITANO"},
    %{name: "HitBTC", slug: "HITBTC"},
    %{name: "Coinnest", slug: "COINNEST"},
    %{name: "WEX", slug: "WEX"},
    %{name: "Lykke", slug: "LYKKE"},
    %{name: "Jubi", slug: "JUBI"},
    %{name: "BitBank", slug: "BITBANK"},
    %{name: "bitFlyerFX", slug: "BITFLYERFX"},
    %{name: "BitMart", slug: "BITMART"},
    %{name: "BTCE", slug: "BTCE"},
    %{name: "BTER", slug: "BTER"},
    %{name: "ABCC", slug: "ABCC"},
    %{name: "Zaif", slug: "ZAIF"},
    %{name: "LocalBitcoins", slug: "LOCALBITCOINS"},
    %{name: "Foxbit", slug: "FOXBIT"},
    %{name: "MtGox", slug: "MTGOX"},
    %{name: "Bit2C", slug: "BIT2C"},
    %{name: "Bluebelt", slug: "BLUEBELT"},
    %{name: "Huobi", slug: "HUOBI"},
    %{name: "Exmo", slug: "EXMO"},
    %{name: "DSX", slug: "DSX"},
    %{name: "Gatecoin", slug: "GATECOIN"},
    %{name: "Cryptsy", slug: "CRYPTSY"},
    %{name: "Luno", slug: "LUNO"},
    %{name: "OpenLedger", slug: "OPENLEDGER"},
    %{name: "LBank", slug: "LBANK"},
    %{name: "Coincap", slug: "COINCAP"},
    %{name: "TuxExchange", slug: "TUXEXCHANGE"},
    %{name: "ExtStock", slug: "EXTSTOCK"},
    %{name: "CoinsBank", slug: "COINSBANK"}
  ]
  def exchanges, do: @exchanges

  def get_torches_limit_for_resolution(resolution) do
    case resolution do
      60 -> 1440
      _ -> 2000
    end
  end

  def get_torches(exchange, base, quote, resolution, to, limit \\ 0) do
    true_limit = if limit == 0, do: @actual_limit, else: limit

    OK.for do
      symbol = "#{exchange}:#{base}:#{quote}"
      [cc_exchange, cc_base, cc_quote] <- to_cryptocompare_list(exchange, base, quote)
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      torches <- Rest.get_torches(rest, cc_exchange, cc_base, cc_quote, resolution, Timex.to_unix(to), true_limit)

      result =
        torches
        |> Enum.map(&to_torch(symbol, resolution, &1))
        |> Enum.filter(&is_nonzero_torch(&1))
    after
      result
    end
  end

  def iterate_torches(base, quote, from, to, resolution, callback) do
    debug_enter(%{base: base, quote: quote, from: from, to: to, resolution: resolution})

    do_iterate_torches(base, quote, from, to, resolution, callback)

    debug_exit()
  end

  defp do_iterate_torches(base, quote, from, to, resolution, callback) do
    success(torches) = get_torches("CRYPTOCOMPARE", base, quote, resolution, to)

    unless Enum.empty?(torches) do
      if is_function(callback) do
        # for testing purpose
        callback.(torches)
      else
        {module, function, arguments} = callback
        apply(module, function, arguments ++ [torches])
      end
    end

    debug_step(%{to: to, torches: length(torches)})

    to =
      if length(torches) < get_torches_limit_for_resolution(resolution) do
        # break iteration
        from
      else
        first_torch = torches |> List.first()

        if first_torch do
          # continue iteration
          first_torch |> Map.get(:timestamp) |> NaiveDateTime.add(-1)
        else
          # break iteration
          from
        end
      end

    if date_lt(from, to) do
      do_iterate_torches(base, quote, from, to, resolution, callback)
    end
  end

  def get_currencies do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      coins <- Rest.get_coins(rest)
    after
      Map.keys(coins)
    end
  end

  def get_ticker_for_exchange(exchange, base, quote) do
    OK.for do
      tickers <- get_tickers_for_exchange(exchange, [base], [quote])
    after
      tickers |> List.first()
    end
  end

  def get_tickers_for_exchange(exchange, base_list, quote_list) do
    OK.for do
      # TODO: also translate base_list and quote_list
      cc_exchange <- to_cryptocompare_name(exchange)
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      tickers_raw <- Rest.get_tickers_for_exchange(rest, cc_exchange, base_list, quote_list)

      tickers =
        tickers_raw
        |> Enum.map(&to_tickers(exchange, elem(&1, 0), elem(&1, 1)))
        |> List.flatten()
    after
      tickers
    end
  end

  def get_tickers() do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      coins <- Rest.get_coins(rest)

      tickers =
        Map.keys(coins)
        |> Enum.chunk_every(50)
        |> Enum.map(&(Rest.get_tickers_for_exchange(rest, "CCCAGG", &1, ["BTC"]) |> unwrap()))
        |> Enum.map(&map_to_tickers(&1))
        |> List.flatten()
        |> Enum.filter(&(get_base(&1.symbol) != get_quote(&1.symbol)))
    after
      tickers
    end
  end

  def get_briefs() do
  end

  def map_to_tickers(map) do
    map |> Enum.map(&to_tickers("CRYPTOCOMPARE", elem(&1, 0), elem(&1, 1)))
  end

  def get_symbols() do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      _pairs <- Rest.get_pairs(rest)
      # TODO
      symbols = []
    after
      symbols
    end
  end

  def get_exchanges() do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      pairs <- Rest.get_pairs(rest)
      exchanges = Map.keys(pairs)
    after
      ([
         %{name: "CCCAGG", slug: "CRYPTOCOMPARE"}
       ] ++ (exchanges |> Enum.map(&%{slug: String.upcase(&1), name: &1})))
      |> Enum.uniq_by(& &1.name)
    end
  end

  defp is_nonzero_torch(torch) do
    #    ["open", "high", "low", "close", "volume"]
    # Note: CRYPTOCOMPARE:DAI:BTC has 0.0 in open, high, low, close
    torch |> Map.take([:open, :high, :low, :close, :volume]) |> Enum.all?(&(elem(&1, 1) != 0.0))
  end

  defp to_torch(symbol, resolution, %{"open" => open, "high" => high, "low" => low, "close" => close, "volumefrom" => volume, "time" => timestamp}) do
    %Torch{
      symbol: symbol,
      open: to_float(open),
      high: to_float(high),
      low: to_float(low),
      close: to_float(close),
      volume: to_float(volume),
      resolution: resolution,
      timestamp: DateTime.to_naive(Timex.from_unix(timestamp))
    }
  end

  defp to_tickers(exchange, base, tickers) do
    tickers |> Enum.map(&to_ticker(exchange, base, elem(&1, 0), elem(&1, 1)))
  end

  defp to_ticker(exchange, base, quote, ticker) do
    %Ticker{
      symbol: "#{exchange}:#{base}:#{quote}",
      # CryptoCompare reports a single price (no bid / ask spread)
      bid: to_float(ticker["PRICE"]),
      ask: to_float(ticker["PRICE"]),
      volume_24h_base: to_float(ticker["VOLUME24HOUR"]),
      volume_24h_quote: to_float(ticker["VOLUME24HOURTO"])
    }
  end

  def get_amount_precision(base, _quote) do
    case base do
      _ -> 8
    end
  end

  def get_price_precision(_base, quote) do
    case quote do
      _ -> 8
    end
  end

  def get_tick(_base, quote) do
    case quote do
      _ -> 0.00000001
    end
  end

  def is_supported(symbol) do
    [exchange, base, quote] = to_list(symbol)

    case to_cryptocompare_list(exchange, base, quote) do
      success(_) -> true
      failure(_) -> false
    end
  end

  defp to_cryptocompare_name(slug) do
    map = @exchanges |> Enum.find(&(&1.slug == slug))

    if map do
      success(map.name)
    else
      failure("Not supported")
    end
  end

  defp to_cryptocompare_list(exchange, base, quote) do
    try do
      #      if base in ["CRB"], do: throw "#{base} currency is not supported by CryptoCompare"
      success(name) = to_cryptocompare_name(exchange)

      base =
        case exchange do
          "BITTREX" ->
            case base do
              "BCC" -> "BCH"
              other -> other
            end

          "BINANCE" ->
            case base do
              "BCC" -> "BCH"
              other -> other
            end

          _other ->
            base
        end

      success([name, base, quote])
    catch
      reason -> failure(reason)
    end
  end

  def get_link(base, _quote) do
    "https://www.cryptocompare.com/coins/#{String.downcase(base)}/overview"
  end
end
