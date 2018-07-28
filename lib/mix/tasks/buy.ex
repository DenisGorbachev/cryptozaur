defmodule Mix.Tasks.Buy do
  use Mix.Task

  @shortdoc "Place a limit buy order"

  def run(args) do
    Mix.Tasks.Place.run(args, &abs(&1))
  end
end
