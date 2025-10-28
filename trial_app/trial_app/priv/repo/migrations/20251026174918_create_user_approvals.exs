defmodule TrialApp.Repo.Migrations.CreateUserApprovals do
  use Ecto.Migration

  def change do
    create table(:user_approvals) do
      add :user_id, :integer, null: false
      add :approved, :boolean, default: false, null: false
      add :approved_at, :utc_datetime

      timestamps()
    end

    create index(:user_approvals, [:user_id])
    create unique_index(:user_approvals, [:user_id], name: :user_approvals_user_id_unique)
  end
end
