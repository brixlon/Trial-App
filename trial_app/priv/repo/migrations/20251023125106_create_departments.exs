defmodule TrialApp.Repo.Migrations.CreateDepartments do
  use Ecto.Migration

  def change do
    create table(:departments) do
      add :name, :string, null: false
      add :description, :text
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      # optional creator/owner
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:departments, [:organization_id])
    create index(:departments, [:user_id])
    create unique_index(:departments, [:name, :organization_id])
  end
end
