# lib/trial_app/eams/team_member.ex
defmodule TrialApp.Eams.TeamMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_members" do
    belongs_to :team, TrialApp.Eams.Team
    belongs_to :user, TrialApp.Accounts.User

    timestamps()
  end

  def changeset(team_member, attrs) do
    team_member
    |> cast(attrs, [:team_id, :user_id])
    |> validate_required([:team_id, :user_id])
    |> unique_constraint([:team_id, :user_id])
  end
end
