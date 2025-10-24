defmodule TrialApp.Orgs.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :first_name, :string
    field :last_name, :string
    field :position, :string
    field :phone, :string
    field :hire_date, :date

    belongs_to :user, TrialApp.Accounts.User
    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :team, TrialApp.Orgs.Team

    timestamps()
  end

  def changeset(employee, attrs) do
    employee
    |> cast(attrs, [:first_name, :last_name, :position, :phone, :hire_date, :user_id, :department_id, :team_id])
    |> validate_required([:first_name, :last_name, :user_id])
    |> unique_constraint(:user_id)
  end
end
