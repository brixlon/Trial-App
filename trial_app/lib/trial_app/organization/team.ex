defmodule TrialApp.Teams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Departments.Department
  alias TrialApp.Employees.Employee
  alias TrialApp.Accounts.User

  schema "teams" do
    field :name, :string
    field :description, :string  # ADD THIS LINE

    belongs_to :department, Department
    belongs_to :user, User # optional creator/owner

    has_many :employees, Employee

    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :department_id, :user_id])  # ADD :description HERE
    |> validate_required([:name, :department_id])
    |> unique_constraint(:name, name: :teams_name_department_id_index)
  end
end
