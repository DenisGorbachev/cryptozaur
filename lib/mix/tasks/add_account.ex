defmodule Mix.Tasks.Add.Account do
  use Mix.Task
  import Mix.Ecto
  import Mix.Tasks.Helpers
  import Cryptozaur.{Utils, Logger}
  alias Cryptozaur.{Repo, Connector, DriverSupervisor}

  @shortdoc "Add account"

  def run(args) do
    %{flags: %{verbose: _verbose}, options: %{name: name, config: config_filename, accounts: accounts_filename}, args: %{exchange: exchange, key: key, secret: secret}} = parse_args(args)
    ensure_repo(Repo, [])
    {:ok, _pid, _apps} = ensure_started(Repo, [])
    {:ok, _pid} = Application.ensure_all_started(:httpoison)
    {:ok, _pid} = Application.ensure_all_started(:ex_rated)
    {:ok, _pid} = DriverSupervisor.start_link([])

    {:ok, _config} = read_json(config_filename)
    {:ok, accounts} = read_json(accounts_filename)

    name = name || String.downcase(exchange)
    exchange = String.upcase(exchange)

    result =
      case Connector.credentials_valid?(exchange, key, secret) do
        {:ok, true} ->
          if !Map.has_key?(accounts, String.to_atom(name)) do
            accounts = accounts |> Map.put(name, %{exchange: exchange, key: key, secret: secret})
            write_json(accounts_filename, accounts)
          else
            {:error, %{message: "Account already exists", name: name}}
          end

        {:error, reason} ->
          {:error, %{message: "Invalid credentials: request for balances failed", reason: reason}}
      end

    case result do
      {:ok, value} -> {:ok, value}
      {:error, error} -> error_step(error)
    end

    result
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
        name: [
          value_name: "name",
          short: "-n",
          long: "--name",
          help: "Account name (arbitrary string used to identify account in Cryptozaur) (default: exchange name)",
          required: false
        ],
        config: [
          value_name: "config",
          short: "-c",
          long: "--config",
          help: "Config filename",
          default: "#{System.user_home!()}/.cryptozaur/config.json",
          required: false
        ],
        accounts: [
          value_name: "accounts",
          short: "-a",
          long: "--accounts",
          help: "Accounts filename",
          default: "#{System.user_home!()}/.cryptozaur/accounts.json",
          required: false
        ]
        #        quote: [
        #          value_name: "quote",
        #          short: "-q",
        #          long: "--quote",
        #          help: "Quote currency",
        #          parser: :string,
        #          required: false,
        #          default: "BTC"
        #        ],
        #        destination: [
        #          value_name: "destination",
        #          short: "-d",
        #          long: "--destination",
        #          help: "Destination (clipboard, console)",
        #          parser: :string,
        #          required: false,
        #          default: "console"
        #        ],
        #        only: [
        #          value_name: "only",
        #          short: "-o",
        #          long: "--only",
        #          help: "Only this symbol (may be specified multiple times)",
        #          parser: :string,
        #          multiple: true,
        #          required: false,
        #          default: []
        #        ],
        #        without: [
        #          value_name: "without",
        #          short: "-w",
        #          long: "--without",
        #          help: "Without this symbol (may be specified multiple times)",
        #          parser: :string,
        #          multiple: true,
        #          required: false,
        #          default: []
        #        ],
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
        #        limit: [
        #          value_name: "limit",
        #          short: "-l",
        #          long: "--limit",
        #          help: "Limit results",
        #          parser: :integer,
        #          required: false,
        #          default: 0
        #        ],
      ]
    )
    |> Optimus.parse!(argv)
  end
end
