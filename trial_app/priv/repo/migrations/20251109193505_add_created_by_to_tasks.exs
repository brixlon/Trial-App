defmodule TrialApp.Repo.Migrations.AddCreatedByToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :created_by_id, references(:users, on_delete: :nilify_all)
    end

    create index(:tasks, [:created_by_id])
  end
end
