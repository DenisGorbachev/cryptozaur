defmodule Cryptozaur.Case do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Cryptozaur.Repo

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Cryptozaur.Case
      alias Cryptozaur.Repo
      alias Ecto.Adapters.SQL.Sandbox
    end
  end

  setup context do
    :ok = Sandbox.checkout(Repo)

    unless context[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    :ok
  end

  setup context do
    config = context[:config] || %{}
    accounts = context[:accounts] || %{}
    [key: key, secret: secret] = Application.get_env(:cryptozaur, :kucoin, key: "", secret: "")
    accounts = accounts |> Map.put(:kucoin, %{exchange: "KUCOIN", key: key, secret: secret})
    [url: _url, key: key, secret: secret] = Application.get_env(:cryptozaur, :leverex, key: "", secret: "")
    accounts = accounts |> Map.put(:leverex, %{exchange: "LEVEREX", key: key, secret: secret})
    context = context |> Map.put(:config, config)
    context = context |> Map.put(:accounts, accounts)

    {:ok, config_filename} = Briefly.create()
    File.write!(config_filename, Poison.encode!(context[:config]))
    {:ok, accounts_filename} = Briefly.create()
    File.write!(accounts_filename, Poison.encode!(context[:accounts]))

    context
    |> Map.put(:opts, ["--config", config_filename, "--accounts", accounts_filename])
    |> Map.put(:config, config)
    |> Map.put(:accounts, accounts)
    |> Map.put(:config_filename, config_filename)
    |> Map.put(:accounts_filename, accounts_filename)
  end

  def raw(records) do
    records |> Enum.map(&Map.take(&1, &1.__struct__.fields()))
  end

  defmacro test_idempotency(arg) do
    quote do
      unquote(arg)
      unquote(arg)
    end
  end

  def produce_driver(mock, module, key \\ Ecto.UUID.generate(), registry \\ Cryptozaur.Drivers) do
    via = {key, module}
    register = fn -> Registry.register(registry, via, true) end
    {:ok, _} = GenServerMock.start_link(mock, register)

    key
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
