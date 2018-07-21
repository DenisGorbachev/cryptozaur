ExUnit.start()

ExUnit.configure(exclude: [local: true])

# Get Mix output sent to the current process via message passing
Mix.shell(Mix.Shell.Process)

Ecto.Adapters.SQL.Sandbox.mode(Cryptozaur.Repo, :manual)

defmodule Cryptozaur.Case do
  use ExUnit.Case

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
end

defmodule GenServerMock do
  @moduledoc false

  use GenServer

  def start_link(mocks, init_handler) do
    GenServer.start_link(__MODULE__, {mocks, init_handler})
  end

  def init({mocks, init_handler}) do
    init_handler.()

    {:ok, mocks}
  end

  def handle_call(request, _, mocks) do
    result = List.keytake(mocks, request, 0)

    if result do
      {{_request, response}, updated_mocks} = result
      {:reply, response, updated_mocks}
    else
      {:error, "No mock for request: #{inspect(request)}"}
    end
  end
end
