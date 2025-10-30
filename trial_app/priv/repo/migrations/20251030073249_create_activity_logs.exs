defmodule TrialApp.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :message, :text, null: false
      add :meta, :map
      timestamps()
    end

    create index(:activity_logs, [:actor_id])
    create index(:activity_logs, [:inserted_at])
  end
end
