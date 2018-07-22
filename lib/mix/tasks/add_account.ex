defmodule Mix.Tasks.Add.Account do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Utils, Logger}
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}

  @shortdoc "Add account"

  def run(args) do
    %{flags: %{verbose: _verbose}, options: %{account_name: account_name, config_filename: config_filename, accounts_filename: accounts_filename}, args: %{exchange: exchange, key: key, secret: secret}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid, _apps} = ensure_started(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, _config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    name = account_name || String.downcase(exchange)
    exchange = String.upcase(exchange)

    result =
      with {:ok, true} <- validate_account_name_unique(name, accounts),
           {:ok, true} <- validate_credentials(exchange, key, secret) do
        accounts = Map.put(accounts, name, %{exchange: exchange, key: key, secret: secret})
        write_json(accounts_filename, accounts)
      end

    case result do
      {:ok, value} -> {:ok, value}
      {:error, error} -> Mix.shell().info("[ERR] " <> to_verbose_string(error))
    end

    result
  end

  def validate_account_name_unique(name, accounts) do
    case !Map.has_key?(accounts, String.to_atom(name)) do
      true -> {:ok, true}
      false -> {:error, %{message: "Account already exists", name: name}}
    end
  end

  def validate_credentials(exchange, key, secret) do
    case Connector.credentials_valid?(exchange, key, secret) do
      {:ok, true} -> {:ok, true}
      {:error, reason} -> {:error, %{message: "Invalid credentials: request for balances failed", reason: reason}}
    end
  end

  def parse_args(argv) do
    exchanges =
      Connector.get_exchanges()
      |> Enum.filter(& &1.is_public)
      |> pluck(:slug)
      |> Enum.sort()
      |> Enum.map(&String.downcase(&1))

    Optimus.new!(
      allow_unknown_args: false,
      parse_double_dash: true,
      args: [
        exchange: [
          value_name: "exchange",
          help: "Exchange (supported: #{exchanges |> Enum.join(", ")})",
          required: true
        ],
        key: [
          value_name: "key",
          help: "API key (generated in exchange interface)",
          required: true
        ],
        secret: [
          value_name: "secret",
          help: "API secret (generated in exchange interface)",
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
        account_name: [
          value_name: "account_name",
          short: "-a",
          long: "--account",
          help: "Account name (arbitrary string used to identify account in Cryptozaur) (default: exchange name)",
          required: false
        ],
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
        #        from: [
        #          value_name: "from",
        #          short: "-f",
        #          long: "--from",
        #          help: "From date",
        #          parser: fn(s) ->
        #                    case NaiveDateTime.from_iso8601(s) do
        #                      {:error, _} -> {:error, "invalid date"}
        #                      {:ok, _} = ok -> ok
        #                    end
        #          end,
        #          required: false,
        #          default: ~N[2009-01-01 00:00:00]
        #        ],
        #        to: [
        #          value_name: "to",
        #          short: "-t",
        #          long: "--to",
        #          help: "To date",
        #          parser: fn(s) ->
        #                    case NaiveDateTime.from_iso8601(s) do
        #                      {:error, _} -> {:error, "invalid date"}
        #                      {:ok, _} = ok -> ok
        #                    end
        #          end,
        #          required: false,
        #          default: now()
        #        ],
      ]
    )
    |> Optimus.parse!(argv)
  end
end
