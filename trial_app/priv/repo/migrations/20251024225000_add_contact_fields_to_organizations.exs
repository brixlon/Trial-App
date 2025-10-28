# Save this as: priv/repo/migrations/20251024225000_add_contact_fields_to_organizations.exs

defmodule TrialApp.Repo.Migrations.AddContactFieldsToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :email, :string
      add :phone, :string
      add :address, :text
    end

    create index(:organizations, [:email])
  end
end
