defmodule TrialApp.Repo.Migrations.CreateProjectAttachees do
  use Ecto.Migration

  def change do
    create table(:project_attachees) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :attachee_id, references(:attachees, on_delete: :delete_all), null: false
      add :role, :string, default: "Intern"
      add :joined_at, :date
      add :left_at, :date

      timestamps()
    end

    create unique_index(:project_attachees, [:project_id, :attachee_id])
    create index(:project_attachees, [:project_id])
    create index(:project_attachees, [:attachee_id])
  end
end
