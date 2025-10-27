defmodule TrialApp.Orgs.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    field :description, :string

    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :team_lead, TrialApp.Accounts.User
    has_many :employees, TrialApp.Orgs.Employee

    # ADDED: Association to assigned users
    has_many :assigned_users, TrialApp.Accounts.User,
      foreign_key: :assigned_team_id

    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :department_id, :team_lead_id])
    |> validate_required([:name, :department_id])
    |> unique_constraint(:name)
  end
end
