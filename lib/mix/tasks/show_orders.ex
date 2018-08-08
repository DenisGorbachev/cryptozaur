defmodule Mix.Tasks.Show.Orders do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Utils, Logger}
  alias TableRex.Table
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}
  alias Cryptozaur.Model.{Account}

  @shortdoc "Show orders"

  def run(args) do
    %{flags: %{verbose: _verbose, short: short}, options: %{config_filename: config_filename, accounts_filename: accounts_filename, format: format}, args: %{account_name: account_name, market: market}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, _config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    with {:ok, %Account{exchange: exchange, key: key, secret: secret}} <- get_account(account_name, accounts),
         {:ok, orders} <- get_orders(exchange, key, secret, market) do
      case format do
        "text" ->
          if length(orders) > 0 do
            orders
            |> Enum.sort_by(&to_unix(&1.timestamp), &>=/2)
            |> Enum.map(&to_row(&1, exchange, short))
            |> Table.new([(short && "O/C") || "Status", (short && "B/S") || "Side", "Pair", "Price", "Amount", "Fill", "Timestamp", "ID"])
            |> Table.put_column_meta(3..5, align: :right)
            |> Table.render!()
          else
            "No orders" <> if market, do: " for #{market} market", else: ""
          end

        "json" ->
          orders
          |> Enum.sort_by(&to_unix(&1.timestamp), &>=/2)
          |> Enum.map(&to_map(&1))
          |> Poison.encode!(pretty: true)

        other ->
          "[ERR] " <> to_verbose_string(improve_error(%{message: "Unsupported format", format: other}))
      end
      |> Mix.shell().info()

      {:ok, orders}
    else
      {:error, error} -> ("[ERR] " <> to_verbose_string(improve_error(error))) |> Mix.shell().info()
    end
  end

  def get_orders(exchange, key, secret, market) do
    if market do
      with {:ok, [base, quote]} <- parse_market(market) do
        Connector.get_orders(exchange, key, secret, base, quote)
      end
    else
      Connector.get_orders(exchange, key, secret)
    end
  end

  def to_row(order, exchange, short) do
    [base, quote] = to_list(order.pair)

    status =
      case order.status do
        "opened" -> (short && "O") || "Open"
        "closed" -> (short && "X") || "Closed"
      end

    side =
      case order.amount_requested > 0.0 do
        true -> (short && "B") || "Buy"
        false -> (short && "S") || "Sell"
      end

    [
      status,
      side,
      order.pair,
      format_price(exchange, base, quote, order.price),
      format_amount(exchange, base, quote, abs(order.amount_requested)),
      format_amount(exchange, base, quote, abs(order.amount_filled)),
      NaiveDateTime.to_string(drop_milliseconds(order.timestamp)),
      order.uid
    ]
  end

  def parse_args(argv) do
    Optimus.new!(
      allow_unknown_args: false,
      parse_double_dash: true,
      args: [
        account_name: [
          value_name: "account",
          help: "Account name",
          required: true
        ],
        market: [
          value_name: "market",
          help: "Market (e.g. LEX:BTC or ETHM18)",
          required: false
        ]
      ],
      flags: [
        verbose: [
          value_name: "verbose",
          short: "-v",
          long: "--verbose",
          help: "Print extra information",
          required: false
        ],
        short: [
          value_name: "short",
          short: "-s",
          long: "--short",
          help: "Improve readability by condensing output",
          required: false
        ]
      ],
      options: [
        config_filename: [
          value_name: "config_filename",
          short: "-c",
          long: "--config",
          help: "Config filename",
          default: "#{System.user_home!()}/.cryptozaur/config.json",
          required: false
        ],
        accounts_filename: [
          value_name: "accounts_filename",
          short: "-u",
          long: "--accounts",
          help: "Accounts filename",
          default: "#{System.user_home!()}/.cryptozaur/accounts.json",
          required: false
        ],
        format: [
          value_name: "format",
          short: "-f",
          long: "--format",
          help: "Format (text, json)",
          required: false,
          default: "text"
        ]
      ]
    )
    |> Optimus.parse!(argv)
  end
end
