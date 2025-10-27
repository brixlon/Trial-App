defmodule TrialApp.Repo.Migrations.AddAssignmentFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :assigned_organization_id, :integer
      add :assigned_department_id, :integer
      add :assigned_team_id, :integer
      add :assigned_role, :string
      add :assigned_position, :string
    end
  end
end
