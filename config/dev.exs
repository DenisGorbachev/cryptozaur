use Mix.Config

config :cryptozaur, :env, :dev

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Configure your database
config :cryptozaur, Cryptozaur.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "cryptozaur",
  # always use username even for dev (the same user as for frontend application)
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

config :pre_commit,
  commands: ["prepare", "test"],
  verbose: true

config :mix_test_watch, clear: true
