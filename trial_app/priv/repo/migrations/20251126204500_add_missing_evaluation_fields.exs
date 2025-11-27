defmodule TrialApp.Repo.Migrations.AddMissingEvaluationFields do
  use Ecto.Migration

  def change do
    alter table(:evaluations) do
      add :evaluation_details, :text
    end
  end
end
