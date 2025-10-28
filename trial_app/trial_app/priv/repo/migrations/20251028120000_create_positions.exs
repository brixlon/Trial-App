defmodule TrialApp.Repo.Migrations.CreatePositions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:positions) do
      add :name, :string, null: false
      add :description, :string
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :naive_datetime)
    end

    # Index creation moved to alignment migration to avoid referencing
    # a non-existent column on legacy databases
  end
end
