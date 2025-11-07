# priv/repo/migrations/20251107xxxxxx_add_task_comments.exs
defmodule TrialApp.Repo.Migrations.AddTaskComments do
  use Ecto.Migration

  def change do
    create table(:task_comments) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :body, :text

      timestamps()
    end

    create index(:task_comments, [:task_id])
    create index(:task_comments, [:user_id])
  end
end
