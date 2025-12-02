defmodule TrialApp.Repo.Migrations.FixAttacheeRoleIds do
  use Ecto.Migration

  def up do
    # Fix role_id for users where active_role is 'attachee' but role_id is not 3
    # The attachee role has id = 3 (as seen in the roles table)
    execute """
    UPDATE users
    SET role_id = 3
    WHERE active_role = 'attachee'
    AND role_id != 3
    """

    # Also fix users where 'attachee' is in the roles array but role_id is not 3
    execute """
    UPDATE users
    SET role_id = 3
    WHERE 'attachee' = ANY(roles)
    AND role_id != 3
    """
  end

  def down do
    # This migration is a data fix, so we don't need to revert it
    # If you really need to revert, you would need to know the original role_id values
    :ok
  end
end
