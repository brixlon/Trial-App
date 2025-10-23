defmodule TrialApp.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string, null: false
      add :department_id, references(:departments, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all) # optional owner/creator

      timestamps(type: :utc_datetime)
    end

    create index(:teams, [:department_id])
    create index(:teams, [:user_id])
    create unique_index(:teams, [:name, :department_id])
  end
end
