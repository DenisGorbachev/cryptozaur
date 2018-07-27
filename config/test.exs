use Mix.Config

config :cryptozaur, :env, :test

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :cryptozaur, Cryptozaur.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "cryptozaur_test",
  # always use username even for dev (the same user as for frontend application)
  username: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :exvcr,
  vcr_cassette_library_dir: "test/fixture/vcr_cassettes",
  filter_url_params: false

if File.exists?("#{Path.dirname(__ENV__.file)}/#{Mix.env()}.secret.exs"), do: import_config("#{Mix.env()}.secret.exs")
if File.exists?("#{Path.dirname(__ENV__.file)}/#{Mix.env()}.local.exs"), do: import_config("#{Mix.env()}.local.exs")
