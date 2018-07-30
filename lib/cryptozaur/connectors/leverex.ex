defmodule Cryptozaur.Connectors.Leverex do
  require OK
  alias Cryptozaur.Model.{Balance, Order}
  alias Cryptozaur.Drivers.LeverexRest, as: Rest

  def get_info(extra \\ []) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      info <- Rest.get_info(rest, extra)
    after
      info
    end
  end

  def get_balances(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      results <- Rest.get_balances(rest)
      balances = Enum.map(results, &to_balance(&1))
    after
      balances
    end
  end

  defp to_balance(%{"asset" => currency, "available_amount" => available_amount, "total_amount" => total_amount}) do
    %Balance{currency: currency, total_amount: total_amount, available_amount: available_amount}
  end

  def get_orders(key, secret, extra \\ []) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      orders <- Rest.get_orders(rest, nil, extra)
    after
      orders |> Enum.map(&to_order(&1))
    end
  end

  defp to_order(order) do
    %Order{
      uid: order["id"],
      pair: order["symbol"],
      price: order["limit_price"],
      base_diff: order["filled_amount"],
      quote_diff: -1 * order["filled_amount"] - order["fee"],
      amount_requested: order["called_amount"],
      amount_filled: order["filled_amount"],
      status: order["filled_amount"],
      timestamp: NaiveDateTime.from_iso8601!(order["inserted_at"])
    }
  end

  def place_order(key, secret, base, quote, amount, price, extra \\ []) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"id" => id} <- Rest.place_order(rest, "#{base}:#{quote}", amount, price, extra)
    after
      to_string(id)
    end
  end

  def cancel_order(key, secret, _base, _quote, uid, extra \\ []) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"id" => id} <- Rest.cancel_order(rest, uid, extra)
    after
      to_string(id)
    end
  end

  #  defp to_symbol(base, quote) do
  #    "LEVEREX:#{to_pair(base, quote)}"
  #  end
  #
  #  defp to_pair(base, quote) do
  #    "#{base}:#{quote}"
  #  end
  #
  def get_min_amount(base, _price) do
    case base do
      _ -> 0.00000001
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

  def get_link(base, quote) do
    "https://www.leverex.io/market/#{base}:#{quote}"
  end
end
