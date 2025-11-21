defmodule TrialApp.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :report_type, :string, null: false
      add :file_path, :string
      add :file_name, :string
      add :period_start, :date
      add :period_end, :date
      add :status, :string, default: "draft"
      add :sent_at, :utc_datetime
      add :viewed_at, :utc_datetime
      add :summary_data, :map, default: %{}

      add :attachee_id, references(:attachees, on_delete: :delete_all), null: false
      add :generated_by_id, references(:users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:reports, [:attachee_id])
    create index(:reports, [:generated_by_id])
    create index(:reports, [:status])
    create index(:reports, [:report_type])
  end
end
