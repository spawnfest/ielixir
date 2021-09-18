import Config

if Mix.env() == :prod do
  config :logger,
    level: :info
else
  config :logger,
    level: :debug
end
