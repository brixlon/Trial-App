defmodule TrialApp.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  def change do
    # If you want to remove all existing users first
    execute("DELETE FROM users", "")

    alter table(:users) do
      add :username, :string, null: false
    end

    create unique_index(:users, [:username])
  end
end
