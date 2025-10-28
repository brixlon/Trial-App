defmodule TrialApp.Repo.Migrations.RenameUserIdToTeamLeadIdInTeams do
  use Ecto.Migration

  def change do
    rename table(:teams), :user_id, to: :team_lead_id
  end
end
