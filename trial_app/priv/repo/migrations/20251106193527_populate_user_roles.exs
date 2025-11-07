# Create this migration file: priv/repo/migrations/TIMESTAMP_populate_user_roles.exs
# Run: mix ecto.gen.migration populate_user_roles

defmodule TrialApp.Repo.Migrations.PopulateUserRoles do
  use Ecto.Migration
  import Ecto.Query
  alias TrialApp.Repo
  alias TrialApp.Accounts.User

  def up do
    # Ensure the roles column exists and is an array
    alter table(:users) do
      modify :roles, {:array, :string}, default: []
      modify :active_role, :string
    end

    # Populate roles array from single role field for existing users
    flush()

    Repo.all(User)
    |> Enum.each(fn user ->
      # If roles array is empty but role field has a value, populate it
      if (is_nil(user.roles) or Enum.empty?(user.roles)) and user.role do
        Repo.update!(
          Ecto.Changeset.change(user, %{
            roles: [user.role],
            active_role: user.role
          })
        )
      end
    end)
  end

  def down do
    # Optionally clear the roles array
    execute "UPDATE users SET roles = '{}', active_role = NULL"
  end
end
