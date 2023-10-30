# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :liveview_counter,
  ecto_repos: [Counter.Repo]

config :liveview_counter, Counter.Repo,
  # database: "liveview_counter_repo",
  database: Path.expand("../liveview_counter_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  show_sensitive_data_on_connection_error: true

# username: "user",
# password: "pass",
# hostname: "localhost"

# Configures the endpoint
config :liveview_counter, LiveviewCounterWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: LiveviewCounterWeb.ErrorHTML, json: LiveviewCounterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LiveviewCounter.PubSub,
  live_view: [signing_salt: "2rQnZ7WM"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
