defmodule TrialApp.Repo.Migrations.UpdateProgramsProjectsAndCreateAttacheePrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :starts_on, :date
      add :ends_on, :date
      add :status, :string, default: "active", null: false
    end

    alter table(:projects) do
      add :supervisor_id, references(:users, on_delete: :nilify_all)
    end

    create index(:projects, [:supervisor_id])

    create table(:attachee_programs) do
      add :attachee_id, references(:attachees, on_delete: :delete_all), null: false
      add :program_id, references(:programs, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:attachee_programs, [:attachee_id, :program_id], name: :attachee_programs_attachee_id_program_id_index)
  end
end
