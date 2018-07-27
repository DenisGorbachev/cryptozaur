defmodule Mix.Tasks.Helpers do
  import Cryptozaur.Utils
  alias Cryptozaur.Model.Account

  def notify(message, type \\ "info") do
    #    if (Mix.shell.cmd("which notify-send") == 0) do
    #      0 = Mix.shell.cmd("notify-send --expire-time 1440000 Leverex '#{message}'")
    #    end
    if Mix.shell().cmd("which zenity") == 0 do
      0 = Mix.shell().cmd("(sleep 1 && wmctrl -F -a 'Leverex notification' -b add,above) & (zenity --#{type} --text='#{message}' --title='Leverex notification')")
    end

    # TODO: implement desktop notification for OSX
  end

  def read_json(filename) do
    case File.read(filename) do
      {:ok, content} -> {:ok, Poison.decode!(content, keys: :atoms)}
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, %{message: "Can't read #{filename}", reason: reason}}
    end
  end

  def write_json(filename, content) do
    File.mkdir_p!(Path.dirname(filename))

    case File.write(filename, Poison.encode!(content, pretty: true) <> "\n") do
      :ok -> {:ok, true}
      {:error, reason} -> {:error, %{message: "Can't write #{filename}", reason: reason}}
    end
  end

  def get_account(account_name, accounts) do
    case accounts[String.to_atom(account_name)] do
      nil -> {:error, %{message: "Account not found", account_name: account_name}}
      account -> {:ok, struct(Account, account)}
    end
  end

  def parse_market(market) do
    result = market |> String.split(":")

    case length(result) do
      2 -> {:ok, result}
      _ -> {:error, %{message: "Market not supported", market: market}}
    end
  end

  def render_order(order) do
    exchange = order.account.exchange
    [base, quote] = to_list(order.pair)
    #    (Filled 20.0 LEX) (Order ID: 43213253)
    "[UID: #{order.uid}] #{(order.amount > 0 && "Buy") || "Sell"} #{format_amount(exchange, base, quote, order.amount_requested)} #{base} at #{format_price(exchange, base, quote, order.price)} #{quote} = #{format_amount(exchange, quote, nil, order.amount_requested * order.price)} #{quote}"
  end
end
