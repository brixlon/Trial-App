defmodule TrialApp.Repo.Migrations.AddDepartmentAndPositionToEmployees do
  use Ecto.Migration

  def change do
    alter table(:employees) do
      add :department_id, references(:departments, on_delete: :nothing)
      add :position, :string
    end
  end
end
