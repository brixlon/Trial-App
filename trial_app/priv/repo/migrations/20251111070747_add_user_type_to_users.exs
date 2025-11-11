defmodule TrialApp.Repo.Migrations.AddUserTypeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :user_type, :string, default: "employee"
      add :organization, :string  # For attachees - their school/university
      add :program, :string       # For attachees - their program name
    end

    create index(:users, [:user_type])
  end
end
