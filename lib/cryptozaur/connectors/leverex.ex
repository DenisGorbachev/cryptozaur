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

  defp to_balance(%{"asset" => currency, "available_amount" => available_amount, "placed_amount" => placed_amount, "withdrawn_amount" => withdrawn_amount}) do
    total_amount = available_amount + placed_amount + withdrawn_amount
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

  def get_orders(key, secret, base, quote, extra \\ []) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      orders <- Rest.get_orders(rest, "#{base}:#{quote}", extra)
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
      quote_diff: order["filled_total"] + order["fee"],
      amount_requested: order["requested_amount"],
      amount_filled: order["filled_amount"],
      status: if(!order["cancelled_at"] and order["filled_amount"] != order["requested_amount"], do: "opened", else: "closed"),
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
      result = Rest.cancel_order(rest, uid, extra)
      %{"id" => id} <- result
    after
      to_string(id)
    end
  end

  def get_deposit_address(key, secret, asset, extra \\ []) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      result = Rest.get_deposit_address(rest, asset, extra)
      %{"address" => address} <- result
    after
      address
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
