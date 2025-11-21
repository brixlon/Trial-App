defmodule TrialApp.Repo.Migrations.AddTaskIdToEvaluations do
  use Ecto.Migration

  def change do
    alter table(:evaluations) do
      add :task_id, references(:tasks, on_delete: :nilify_all)
    end

    create index(:evaluations, [:task_id])
  end
end
