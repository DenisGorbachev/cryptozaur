defmodule Cryptozaur.Connectors.Mtgox do
  import OK, only: [success: 1]

  import Cryptozaur.Utils
  alias Cryptozaur.Model.Level

  def credentials_valid?(key, secret) do
    success(key == "key" && secret == "secret")
  end

  def get_latest_trades(_base, _quote) do
    success([])
  end

  def get_levels(base, quote) do
    timestamp = now()

    success({
      [
        %Level{
          symbol: "MTGOX:#{base}:#{quote}",
          price: 90.0,
          amount: 1.0,
          timestamp: timestamp
        }
      ],
      [
        %Level{
          symbol: "MTGOX:#{base}:#{quote}",
          price: 110.0,
          amount: -1.0,
          timestamp: timestamp
        }
      ]
    })
  end

  def place_order(_key, _secret, _base, _quote, _amount, _price, _extra \\ %{}) do
    success(Ecto.UUID.generate())
  end

  def cancel_order(_key, _secret, _base, _quote, uid) do
    success(uid)
  end

  def get_orders(_key, _secret, _base, _quote) do
    success([])
  end

  def get_orders(_key, _secret) do
    success([])
  end

  def validate_order(_base, _quote, _amount, _price) do
    success(nil)
  end

  def get_min_price(_base, quote) do
    case quote do
      "BTC" -> 0.00000001
      "ETH" -> 0.00000001
      "USDT" -> 0.00000001
    end
  end

  def get_min_amount(base, _price) do
    case base do
      _ -> 0.00100000
    end
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
end
