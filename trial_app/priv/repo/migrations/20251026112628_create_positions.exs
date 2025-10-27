defmodule TrialApp.Repo.Migrations.CreatePositions do
  use Ecto.Migration

  def change do
    create table(:positions) do
      add :title, :string, null: false
      add :description, :text
      add :department_id, references(:departments, on_delete: :nilify_all), null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:positions, [:title])
    create index(:positions, [:department_id])
  end
end
