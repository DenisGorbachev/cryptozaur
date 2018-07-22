ExUnit.start()

ExUnit.configure(exclude: [local: true])

# Get Mix output sent to the current process via message passing
Mix.shell(Mix.Shell.Process)

Ecto.Adapters.SQL.Sandbox.mode(Cryptozaur.Repo, :manual)
