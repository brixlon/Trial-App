defmodule TrialApp.Repo.Migrations.AddEvaluationPeriodTracking do
  use Ecto.Migration

  def change do
    alter table(:evaluations) do
      add :evaluation_period_start, :date
      add :evaluation_period_end, :date
      add :is_final, :boolean, default: false
      add :month_1_score, :integer
      add :month_2_score, :integer
      add :month_3_score, :integer
      add :month_1_tasks_count, :integer, default: 0
      add :month_2_tasks_count, :integer, default: 0
      add :month_3_tasks_count, :integer, default: 0
    end

    # Ensure one evaluation per attachee per period
    create unique_index(
             :evaluations,
             [:attachee_id, :evaluation_period_start, :evaluation_period_end],
             name: :evaluations_attachee_period_unique_index,
             where: "is_final = true"
           )

    create index(:evaluations, [:evaluation_period_start])
    create index(:evaluations, [:evaluation_period_end])
    create index(:evaluations, [:is_final])
  end
end
