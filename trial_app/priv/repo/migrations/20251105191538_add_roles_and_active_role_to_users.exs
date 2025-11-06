defmodule TrialApp.Repo.Migrations.AddRolesAndActiveRoleToUsers do
  use Ecto.Migration

  def change do
    # Add the new columns
    alter table(:users) do
      add :roles, {:array, :string}, default: ["attachee"], null: false
      add :active_role, :string, default: "attachee", null: false
    end

    # Backfill existing users with default values
    # (Maps old 'role' field to new 'roles' array, if you had a single role before)
    execute """
    UPDATE users
    SET
      roles = CASE
        WHEN role = 'admin' THEN ARRAY['admin', 'attachee']
        WHEN role = 'supervisor' THEN ARRAY['supervisor', 'attachee']
        WHEN role = 'attachee' THEN ARRAY['attachee']
        ELSE ARRAY['attachee']
      END,
      active_role = COALESCE(role, 'attachee')
    WHERE role IS NOT NULL;
    """

    # Set defaults for any users without a role field
    execute """
    UPDATE users
    SET
      roles = ARRAY['attachee'],
      active_role = 'attachee'
    WHERE roles IS NULL;
    """

    # Optional: Drop the old 'role' column if you had one (uncomment if exists)
    # alter table(:users) do
    #   remove :role
    # end
  end
end
