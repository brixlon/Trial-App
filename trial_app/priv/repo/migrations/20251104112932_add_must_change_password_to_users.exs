defmodule TrialApp.Repo.Migrations.AddMustChangePasswordToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :must_change_password, :boolean, default: false, null: false
      add :password_changed_at, :utc_datetime
    end

    # Index for quick lookups (optional but good practice)
    create index(:users, [:must_change_password])

    # Backfill existing users so none are forced to change password unexpectedly
    execute("""
    UPDATE users
    SET must_change_password = FALSE,
        password_changed_at = NOW()
    WHERE password_changed_at IS NULL;
    """)
  end
end
