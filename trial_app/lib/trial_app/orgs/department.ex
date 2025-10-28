defmodule TrialApp.Orgs.Department do
  use Ecto.Schema
  import Ecto.Changeset

  schema "departments" do
    field :name, :string
    field :description, :string

    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :user, TrialApp.Accounts.User
    belongs_to :manager, TrialApp.Accounts.User

    has_many :teams, TrialApp.Orgs.Team
    has_many :employees, TrialApp.Orgs.Employee
    has_many :positions, TrialApp.Orgs.Position

    timestamps()
  end

  def changeset(department, attrs) do
    department
    |> cast(attrs, [:name, :description, :organization_id, :user_id, :manager_id])
    |> validate_required([:name, :organization_id])
    |> assoc_constraint(:organization)
    |> unique_constraint(:name, name: :departments_name_organization_id_index)
  end
end
