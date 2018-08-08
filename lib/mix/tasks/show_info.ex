defmodule Mix.Tasks.Show.Info do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Logger}
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}

  @shortdoc "Show exchange info"

  def run(args) do
    %{flags: %{verbose: _verbose}, options: %{config_filename: config_filename, accounts_filename: accounts_filename}, args: %{account_name: account_name}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, _config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    result =
      with {:ok, %{exchange: exchange}} <- get_account(account_name, accounts),
           {:ok, info} <- Connector.get_info(exchange) do
        info
        |> Poison.encode!(pretty: true)
        |> Mix.shell().info()

        {:ok, info}
      end

    case result do
      {:ok, value} -> {:ok, value}
      {:error, error} -> Mix.shell().info("[ERR] " <> to_verbose_string(improve_error(error))) && (Mix.env() != :test && exit({:shutdown, 1}))
    end

    result
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
        #        without_dust: [
        #          value_name: "without_dust",
        #          short: "-d",
        #          long: "--without-dust",
        #          help: "Without dust (dust amount is specified in config)",
        #          default: false,
        #          required: false
        #        ],
      ]
    )
    |> Optimus.parse!(argv)
  end
end
