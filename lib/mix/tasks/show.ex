defmodule Mix.Tasks.Show do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Utils, Logger}
  alias TableRex.Table
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}
  alias Cryptozaur.Model.{Account}

  @shortdoc "Show orders"

  def run(args) do
    %{flags: %{verbose: _verbose}, options: %{config_filename: config_filename, accounts_filename: accounts_filename}, args: %{account_name: account_name, market: market}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid, _apps} = ensure_started(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, _config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    with {:ok, %Account{exchange: exchange, key: key, secret: secret}} <- get_account(account_name, accounts),
         {:ok, orders} <- get_orders(exchange, key, secret, market) do
      orders
      |> Enum.sort_by(&to_unix(&1.timestamp), &>=/2)
      |> Enum.map(&order_to_row(&1, exchange))
      |> Table.new()
      |> Table.put_column_meta(2..4, align: :right)
      |> Table.render!()
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

  def order_to_row(order, exchange) do
    [base, quote] = to_list(order.pair)

    status =
      case order.status do
        "opened" -> "O"
        "closed" -> "X"
      end

    side = if order.amount_requested > 0.0, do: "+", else: "-"
    [status, side, format_price(exchange, base, quote, order.price), format_amount(exchange, base, quote, order.amount_filled), format_amount(exchange, base, quote, order.amount_requested), inspect(order.timestamp), order.uid]
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
        ]
      ]
    )
    |> Optimus.parse!(argv)
  end
end
