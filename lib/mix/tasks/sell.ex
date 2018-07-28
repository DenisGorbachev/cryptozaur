defmodule Mix.Tasks.Sell do
  use Mix.Task

  @shortdoc "Place a limit sell order"

  def run(args) do
    Mix.Tasks.Place.run(args, &(-1.0 * abs(&1)))
  end
end
