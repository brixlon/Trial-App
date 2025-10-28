defmodule TrialApp.Repo.Migrations.AddManagementFields do
  use Ecto.Migration

  def change do
    # Organizations - add management fields
    alter table(:organizations) do
      add :is_active, :boolean, default: true, null: false
      add :code, :string, size: 10
    end

    # Departments - add management fields
    alter table(:departments) do
      add :code, :string, size: 10
      add :is_active, :boolean, default: true, null: false
    end

    # Teams - add management fields and direct organization reference
    alter table(:teams) do
      add :code, :string, size: 10
      add :is_active, :boolean, default: true, null: false
      add :team_type, :string, default: "general"
      add :organization_id, references(:organizations, on_delete: :nothing)
    end

    # Employees - add management fields
    alter table(:employees) do
      add :is_active, :boolean, default: true, null: false
      add :status, :string, default: "active"
    end

    # Create indexes for unique codes within organizations
    create index(:organizations, [:code], unique: true, where: "code IS NOT NULL")
    create index(:departments, [:organization_id, :code], unique: true, where: "code IS NOT NULL")
    create index(:teams, [:organization_id, :code], unique: true, where: "code IS NOT NULL")

    # Create index for team organization foreign key
    create index(:teams, [:organization_id])
  end
end
