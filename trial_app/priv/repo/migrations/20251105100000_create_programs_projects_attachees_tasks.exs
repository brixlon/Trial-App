defmodule TrialApp.Repo.Migrations.CreateProgramsProjectsAttacheesTasks do
  use Ecto.Migration

  def change do
    create table(:programs) do
      add :name, :string, null: false
      add :description, :text
      add :code, :string, size: 16
      add :is_active, :boolean, default: true, null: false

      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :department_id, references(:departments, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:programs, [:organization_id])
    create index(:programs, [:department_id])
    create unique_index(:programs, [:name, :department_id], name: :programs_name_department_id_index)
    create unique_index(:programs, [:code, :organization_id], where: "code IS NOT NULL", name: :programs_code_organization_id_index)

    create table(:projects) do
      add :name, :string, null: false
      add :description, :text
      add :code, :string, size: 16
      add :is_active, :boolean, default: true, null: false
      add :starts_on, :date
      add :ends_on, :date

      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :department_id, references(:departments, on_delete: :delete_all), null: false
      add :program_id, references(:programs, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:projects, [:organization_id])
    create index(:projects, [:department_id])
    create index(:projects, [:program_id])
    create unique_index(:projects, [:name, :program_id], name: :projects_name_program_id_index)
    create unique_index(:projects, [:code, :organization_id], where: "code IS NOT NULL", name: :projects_code_organization_id_index)

    create table(:attachees) do
      add :status, :string, default: "active", null: false
      add :starts_on, :date
      add :ends_on, :date

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :department_id, references(:departments, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:attachees, [:user_id])
    create index(:attachees, [:organization_id])
    create index(:attachees, [:department_id])
    create unique_index(:attachees, [:user_id, :department_id], name: :attachees_user_id_department_id_index)

    create table(:tasks) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending", null: false
      add :due_on, :date

      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :assignee_id, references(:attachees, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:tasks, [:project_id])
    create index(:tasks, [:assignee_id])
  end
end
