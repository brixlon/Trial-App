defmodule TrialApp.Departments.Department do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Organizations.Organization
  alias TrialApp.Teams.Team
  alias TrialApp.Accounts.User

  schema "departments" do
    field :name, :string
    field :description, :string

    belongs_to :organization, Organization
    belongs_to :user, User  
    has_many :teams, Team

    timestamps()
  end

  def changeset(dept, attrs) do
    dept
    |> cast(attrs, [:name, :description, :organization_id, :user_id])
    |> validate_required([:name, :organization_id])
    |> unique_constraint(:name, name: :departments_name_organization_id_index)
  end
end
