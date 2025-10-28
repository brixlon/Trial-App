defmodule TrialApp.Repo.Migrations.AddManagerIdToDepartments do
  use Ecto.Migration

  def change do
    alter table(:departments) do
      add :manager_id, references(:users, on_delete: :nilify_all)
    end

    create index(:departments, [:manager_id])
  end
end
