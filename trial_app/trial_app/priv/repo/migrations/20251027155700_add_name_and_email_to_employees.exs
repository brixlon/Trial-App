defmodule TrialApp.Repo.Migrations.AddNameAndEmailToEmployees do
  use Ecto.Migration

  def change do
    # First add columns as nullable
    alter table(:employees) do
      add :name, :string
      add :email, :string
    end

    # Backfill existing data before making NOT NULL
    execute """
      UPDATE employees
      SET name = COALESCE(users.username, users.email),
          email = users.email
      FROM users
      WHERE employees.user_id = users.id
    """

    # Now make them NOT NULL
    alter table(:employees) do
      modify :name, :string, null: false
      modify :email, :string, null: false
    end
  end
end
