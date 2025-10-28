defmodule TrialApp.Orgs.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :name, :string
    field :email, :string
    field :role, :string
    field :position, :string

    belongs_to :user, TrialApp.Accounts.User
    belongs_to :team, TrialApp.Orgs.Team
    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :organization, TrialApp.Orgs.Organization

    timestamps()
  end

  def changeset(employee, attrs) do
    employee
    |> cast(attrs, [:name, :email, :role, :position, :user_id, :team_id, :department_id, :organization_id])
    |> validate_required([:name, :email, :user_id, :team_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> assoc_constraint(:user)
    |> assoc_constraint(:team)
    |> assoc_constraint(:department)
    |> assoc_constraint(:organization)
    |> unique_constraint([:user_id, :team_id])
  end
end
