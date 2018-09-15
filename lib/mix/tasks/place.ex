defmodule Mix.Tasks.Place do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Utils, Logger}
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}
  alias Cryptozaur.Model.{Account, Order}

  @shortdoc "Place an order"

  def run(args, amount_normalizer \\ &identity/1) do
    %{flags: %{verbose: _verbose}, options: %{config_filename: config_filename, accounts_filename: accounts_filename, format: format}, args: %{account_name: account_name, market: market, price: price, amount: amount}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    :ok = put_config(config)

    with {:ok, %Account{exchange: exchange, key: key, secret: secret} = account} <- get_account(account_name, accounts),
         {:ok, [base, quote]} <- parse_market(market),
         amount = amount_normalizer.(amount),
         {:ok, uid} <- Connector.place_order(exchange, key, secret, base, quote, amount, price) do
      order = %Order{
        uid: uid,
        pair: "#{base}:#{quote}",
        price: price,
        amount_requested: amount,
        account: account
      }

      case format do
        "text" -> order_to_string(order)
        "json" -> order |> to_map() |> Poison.encode!(pretty: true)
        other -> "[ERR] " <> to_verbose_string(improve_error(%{message: "Unsupported format", format: other}))
      end
      |> Mix.shell().info()

      {:ok, order}
    else
      {:error, error} -> ("[ERR] " <> to_verbose_string(improve_error(error))) |> Mix.shell().info() && (Mix.env() != :test && exit({:shutdown, 1})) || {:error, error}
    end
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
          required: true
        ],
        price: [
          value_name: "price",
          help: "Price",
          required: true,
          parser: :float
        ],
        amount: [
          value_name: "amount",
          help: "Amount",
          required: true,
          parser: :float
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
