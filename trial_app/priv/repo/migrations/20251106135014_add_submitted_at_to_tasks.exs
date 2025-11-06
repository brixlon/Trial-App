defmodule TrialApp.Repo.Migrations.AddSubmittedAtToTasks do
  use Ecto.Migration

  def change do
  alter table(:tasks) do
    add :submitted_at, :utc_datetime
  end
end
end
