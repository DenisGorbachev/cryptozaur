defmodule Mix.Tasks.Get.Address do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Logger}
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}
  alias Cryptozaur.Model.{Account}

  @shortdoc "Get deposit address"

  def run(args) do
    %{flags: %{verbose: _verbose}, options: %{config_filename: config_filename, accounts_filename: accounts_filename, format: format}, args: %{account_name: account_name, asset: asset}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, _config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    with {:ok, %Account{exchange: exchange, key: key, secret: secret}} <- get_account(account_name, accounts),
         {:ok, address} <- Connector.get_deposit_address(exchange, key, secret, asset) do
      case format do
        "text" ->
          "[Deposit address: #{address}]"

        "json" ->
          %{address: address}
          |> Poison.encode!(pretty: true)

        other ->
          "[ERR] " <> to_verbose_string(improve_error(%{message: "Unsupported format", format: other}))
      end
      |> Mix.shell().info()

      {:ok, address}
    else
      {:error, error} -> (("[ERR] " <> to_verbose_string(improve_error(error))) |> Mix.shell().info() && (Mix.env() != :test && exit({:shutdown, 1}))) || {:error, error}
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
        asset: [
          value_name: "asset",
          help: "Asset (e.g. BTC or ETH)",
          required: true
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
