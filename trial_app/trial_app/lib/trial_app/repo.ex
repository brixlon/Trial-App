defmodule TrialApp.Repo do
  use Ecto.Repo,
    otp_app: :trial_app,
    adapter: Ecto.Adapters.Postgres
end
