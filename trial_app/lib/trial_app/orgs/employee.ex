defmodule TrialApp.Orgs.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :hire_date, :date
    field :role, :string  # e.g. "Software Engineer", "Team Lead" — optional

    belongs_to :user, TrialApp.Accounts.User
    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :team, TrialApp.Orgs.Team
    belongs_to :position, TrialApp.Orgs.Position  # links to positions table

    timestamps()
  end

  @required_fields ~w(first_name last_name user_id)a
  @optional_fields ~w(phone hire_date role organization_id department_id team_id position_id)a

  def changeset(employee, attrs) do
    employee
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:department_id)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:position_id)
  end
end
