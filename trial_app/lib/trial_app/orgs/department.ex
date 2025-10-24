defmodule TrialApp.Orgs.Department do
  use Ecto.Schema
  import Ecto.Changeset

  schema "departments" do
    field :name, :string
    field :description, :string

    belongs_to :manager, TrialApp.Accounts.User
    has_many :teams, TrialApp.Orgs.Team
    has_many :employees, TrialApp.Orgs.Employee

    timestamps()
  end

  def changeset(department, attrs) do
    department
    |> cast(attrs, [:name, :description, :manager_id])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
