defmodule TrialApp.Repo.Migrations.AddOrganizationToEmployees do
  use Ecto.Migration

  def change do
    alter table(:employees) do
      # ✅ Add only what’s missing
      add :organization_id, references(:organizations, on_delete: :delete_all)
    end

    # ✅ Index for faster lookups
    create index(:employees, [:organization_id])
  end
end
