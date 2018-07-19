defmodule Mix.Tasks.Reset do
  use Mix.Task

  @shortdoc "Reset both :dev and :test environments"

  @doc false
  def run(_args) do
    0 = Mix.shell().cmd("MIX_ENV=dev mix ecto.reset")
    0 = Mix.shell().cmd("MIX_ENV=test mix ecto.reset")
  end
end
