defmodule TrialApp.Orgs.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field :name, :string
    field :description, :string

    has_many :departments, TrialApp.Orgs.Department
    has_many :teams, through: [:departments, :teams]
    has_many :employees, TrialApp.Orgs.Employee

    timestamps()
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
