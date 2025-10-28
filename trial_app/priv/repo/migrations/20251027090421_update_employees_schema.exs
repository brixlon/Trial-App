defmodule TrialApp.Repo.Migrations.UpdateEmployeesSchema do
  use Ecto.Migration

  def change do
    alter table(:employees) do
      # Remove fields only if still present
      remove :name, :string
      remove :email, :string

      # Do NOT add position or organization_id again — they already exist
      # Just enforce user_id not null
      modify :user_id, :bigint, null: false
    end

    # Drop email index if it still exists
    drop_if_exists index(:employees, [:email])
  end
end
