defmodule TrialApp.Employees.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Teams.Team
  alias TrialApp.Departments.Department
  alias TrialApp.Accounts.User

  schema "employees" do
    field :name, :string
    field :email, :string
    field :role, :string        # e.g. Admin, Staff, Manager
    field :position, :string    # e.g. Developer, Designer, etc.

    belongs_to :department, Department
    belongs_to :team, Team
    belongs_to :user, User      # the user associated with this employee

    timestamps()
  end

  def changeset(emp, attrs) do
    emp
    |> cast(attrs, [:name, :email, :role, :position, :department_id, :team_id, :user_id])
    |> validate_required([:name, :email, :department_id, :team_id])
    |> unique_constraint(:email)
  end
end
