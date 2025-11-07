defmodule TrialApp.Repo.Migrations.CreateEvaluations do
  use Ecto.Migration

  def change do
    create table(:evaluations) do
      add :score, :integer
      add :comments, :text
      add :attachee_id, references(:attachees, on_delete: :nothing)
      add :evaluator_id, references(:users, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:evaluations, [:user_id])

    create index(:evaluations, [:attachee_id])
    create index(:evaluations, [:evaluator_id])
  end
end
