defmodule TrialApp.Repo.Migrations.CreateEmployees do
  use Ecto.Migration

  def change do
    create table(:employees) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :role, :string
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      # optional creator/admin
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:employees, [:team_id])
    create index(:employees, [:user_id])
    create unique_index(:employees, [:email])
  end
end
