defmodule TrialApp.Repo.Migrations.AddStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, default: "pending", null: false
      add :role, :string, default: "user", null: false
    end

    # Create index for faster queries on status
    create index(:users, [:status])
    create index(:users, [:role])
  end
end
