defmodule TrialApp.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field :name, :string
    field :description, :string

    has_many :departments, TrialApp.Departments.Department

    timestamps()
  end

  def changeset(org, attrs) do
    org
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
