# priv/repo/migrations/20251107xxxxxx_create_teams_and_team_members.exs
defmodule TrialApp.Repo.Migrations.CreateTeamsAndTeamMembers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:teams) do
      add :name, :string, null: false
      add :supervisor_id, references(:users, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:team_members) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:team_members, [:team_id, :user_id])
  end
end
