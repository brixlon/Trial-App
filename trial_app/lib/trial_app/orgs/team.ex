defmodule TrialApp.Orgs.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    field :description, :string

    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :team_lead, TrialApp.Accounts.User
    has_many :employees, TrialApp.Orgs.Employee

    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :department_id, :team_lead_id])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
