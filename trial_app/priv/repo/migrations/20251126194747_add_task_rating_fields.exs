defmodule TrialApp.Repo.Migrations.AddTaskRatingFields do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      # poor, below_average, average, meets_expectations, exceeds_expectations
      add :rating, :string
      add :rating_comment, :text
      add :rated_at, :utc_datetime
      add :rated_by_id, :bigint
    end

    create index(:tasks, [:rated_by_id])
    create index(:tasks, [:rating])
    create index(:tasks, [:rated_at])

    # Add foreign key constraint
    execute "ALTER TABLE tasks ADD CONSTRAINT tasks_rated_by_id_fkey FOREIGN KEY (rated_by_id) REFERENCES users(id) ON DELETE SET NULL",
            "ALTER TABLE tasks DROP CONSTRAINT tasks_rated_by_id_fkey"
  end
end
