defmodule TrialApp.Repo.Migrations.CreateDailyReports do
  use Ecto.Migration

  def change do
    create table(:daily_reports) do
      add :report_date, :date, null: false
      add :summary, :text
      add :tasks_completed, :text
      add :challenges, :text
      add :next_day_plans, :text
      add :status, :string, default: "draft", null: false

      add :team_lead_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :supervisor_id, references(:users, on_delete: :nilify_all), null: false
      add :department_id, references(:departments, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:daily_reports, [:team_lead_id])
    create index(:daily_reports, [:team_id])
    create index(:daily_reports, [:supervisor_id])
    create index(:daily_reports, [:department_id])
    create index(:daily_reports, [:report_date])
    create unique_index(:daily_reports, [:team_lead_id, :team_id, :report_date], name: :daily_reports_team_lead_team_date_index)
  end
end
