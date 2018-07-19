defmodule Cryptozaur.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  use Application
  import Supervisor.Spec
  alias Cryptozaur.DriverSupervisor

  def start(_type, _args) do
    # List all child processes to be supervised
    Apex.ap("asrtarst", numbers: false)

    children =
      [
        supervisor(Cryptozaur.Repo, [])
      ] ++ application_modules()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cryptozaur.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def application_modules() do
    if Application.get_env(:cryptozaur, :env) != :test do
      [
        DriverSupervisor
      ]
    else
      []
    end
  end
end
