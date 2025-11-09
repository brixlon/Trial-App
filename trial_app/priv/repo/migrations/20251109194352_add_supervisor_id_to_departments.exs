defmodule TrialApp.Repo.Migrations.AddSupervisorIdToDepartments do
  use Ecto.Migration

  def change do
    alter table(:departments) do
      add :supervisor_id, references(:users, on_delete: :nilify_all)
    end

    create index(:departments, [:supervisor_id])
  end
end
