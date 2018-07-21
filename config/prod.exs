use Mix.Config

config :cryptozaur, :env, :prod

# Do not print debug messages in production
config :logger, level: :info

if File.exists?("#{Path.dirname(__ENV__.file)}/#{Mix.env()}.secret.exs"), do: import_config("#{Mix.env()}.secret.exs")
if File.exists?("#{Path.dirname(__ENV__.file)}/#{Mix.env()}.local.exs"), do: import_config("#{Mix.env()}.local.exs")
