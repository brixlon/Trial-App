import Config

# Configure your database
config :trial_app, TrialApp.Repo,
  username: "postgres",
  password: "developer",
  hostname: "localhost",
  database: "trial_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure Gmail SMTP for email
config :trial_app, TrialApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  username: "mutindasam39@gmail.com",
  password: "bupihsikglqbzpll",
  ssl: false,
  tls: :always,
  auth: :always,
  port: 587,
  retries: 2,
  tls_options: [
    verify: :verify_none  # For development only
  ]

# For development, we disable any cache and enable
# debugging and code reloading.
config :trial_app, TrialAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "K1xMIhST42Vi3YuVeaBbkdZIGRW5lsiDr0eRwfqPL9uZ6OTNmswb05leTaSSvRxf",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:trial_app, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:trial_app, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :trial_app, TrialAppWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/trial_app_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :trial_app, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
