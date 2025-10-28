defmodule TrialApp.Orgs.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field :name, :string
    field :description, :string
    field :is_active, :boolean, default: true
    field :code, :string

    has_many :departments, TrialApp.Orgs.Department, on_delete: :delete_all
    has_many :teams, through: [:departments, :teams]
    has_many :employees, TrialApp.Orgs.Employee

    timestamps()
  end

  @doc """
  Standard changeset for organization operations.
  """
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :description, :code, :is_active])
    |> validate_required([:name])
    |> validate_length(:code, min: 2, max: 10)
    |> unique_constraint(:name)
    |> unique_constraint(:code)
  end

  @doc """
  Changeset for creating a new organization with additional validations.
  """
  def create_changeset(organization, attrs) do
    organization
    |> changeset(attrs)
    |> validate_required([:code])
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/,
      message: "must contain only uppercase letters, numbers, and underscores")
  end

  @doc """
  Changeset for updating organization with management support.
  """
  def update_changeset(organization, attrs) do
    organization
    |> changeset(attrs)
  end

  @doc """
  Returns a organization with all relationships preloaded for admin dashboard.
  """
  def with_preloads(organization) do
    TrialApp.Repo.preload(organization, [
      :departments,
      :teams,
      :employees
    ])
  end
end
