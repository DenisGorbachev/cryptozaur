defmodule Cryptozaur.Connectors.Block do

  alias Cryptozaur.Model.{Ticker}
  alias Cryptozaur.Drivers.BlockRest, as: Rest

  def get_tickers(params) do
    with {:ok, raw_tickers} <- Rest.get_tickers(params) do
      # Filter out tickers without "symbol_pair" (workaround for Block API bug)
      raw_tickers = raw_tickers |> Enum.filter(&(&1 |> Map.get("symbol_pair") != nil))
      {:ok, Enum.map(raw_tickers, &to_ticker/1)}
    end
  end

  defp to_ticker(%{"base_volume" => base_volume, "market" => exchange, "symbol_pair" => pair, "bid" => bid, "ask" => ask}) do
    %Ticker{
      symbol: to_symbol(exchange, pair),
      bid: (bid || 0) / 1,
      ask: (ask || 0) / 1,
      volume_24h_base: (base_volume || 0) / 1,
      volume_24h_quote: nil
    }
  end

  def symbol_supported?(exchange, base, quote) do
    with {:ok, data} <- Rest.get_tickers(%{market_pair: to_block_symbol(exchange, base, quote)}) do
      {:ok, not Enum.empty?(data)}
    end
  end

  def exchange_supported?(exchange) do
    exchange in get_supported_exchanges()
    # or use Rest.get_markets for fresh data
  end

  def get_supported_exchanges,
    do: [
      "BINANCE",
      "UPBIT",
      "OKEX",
      "BITFINEX",
      "BITHUMB",
      "HUOBIPRO",
      "GDAX",
      "BITTREX",
      "KRAKEN",
      "HITBTC",
      "BITSTAMP",
      "ZB",
      "BIT-Z",
      "POLONIEX",
      "BITFLYER",
      "COINONE",
      "QUOINE",
      "ZAIF",
      "FISCO",
      "BTCBOX",
      "LBANK",
      "GEMINI",
      "EXX",
      "COINCHECK",
      "COINEGG",
      "WEX",
      "COINSBANK",
      "KUCOIN",
      "BITBANK",
      "KORBIT",
      "EXMO",
      "GATE-IO",
      "BIBOX",
      "LIQUI",
      "AEX",
      "CEX-IO",
      "LIVECOIN",
      "ITBIT",
      "UNCOINEX",
      "BTC-MARKETS",
      "TIDEX",
      "HKSY",
      "CRYPTOPIA",
      "XBTCE",
      "BTCTRADE-IM",
      "GETBTC",
      "BX-THAILAND",
      "LAKEBTC",
      "QBTC",
      "LUNO",
      "FATBTC",
      "KEX",
      "QUADRIGACX",
      "COOLCOIN",
      "BIGONE",
      "RIGHTBTC",
      "COINNEST",
      "COINYEE",
      "ACX-IO",
      "ALLCOIN",
      "COIN2COIN",
      "OKCOINCOM",
      "COIN900",
      "COBINHOOD",
      "BIT2C",
      "BRAZILIEX",
      "BTCC",
      "ETHERDELTA",
      "BISQ",
      "HIB8",
      "BITBAY"
    ]

  defp to_symbol(exchange, pair) do
    [base, quote] = String.split(pair, "_")
    "#{String.upcase(exchange)}:#{base}:#{quote}"
  end

  defp to_block_symbol(exchange, base, quote), do: "#{exchange}_#{base}_#{quote}"
end
