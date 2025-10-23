defmodule TrialApp.Employees.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Teams.Team
  alias TrialApp.Accounts.User

  schema "employees" do
    field :name, :string
    field :email, :string
    field :role, :string

    belongs_to :team, Team
    belongs_to :user, User # creator/admin

    timestamps()
  end

  def changeset(emp, attrs) do
    emp
    |> cast(attrs, [:name, :email, :role, :team_id, :user_id])
    |> validate_required([:name, :email, :team_id])
    |> unique_constraint(:email)
  end
end
