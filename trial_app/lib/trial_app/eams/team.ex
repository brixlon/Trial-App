# lib/trial_app/eams/team.ex
defmodule TrialApp.Eams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    belongs_to :supervisor, TrialApp.Accounts.User
    has_many :team_members, TrialApp.Eams.TeamMember

    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :supervisor_id])
    |> validate_required([:name, :supervisor_id])
  end
end
