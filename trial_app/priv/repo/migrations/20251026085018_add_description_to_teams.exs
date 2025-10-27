defmodule TrialApp.Repo.Migrations.AddDescriptionToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :description, :text
    end
  end
end

