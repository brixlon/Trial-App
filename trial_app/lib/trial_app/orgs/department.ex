defmodule TrialApp.Orgs.Department do
  use Ecto.Schema
  import Ecto.Changeset

  schema "departments" do
    field :name, :string
    field :description, :string
    field :code, :string
    field :is_active, :boolean, default: true

    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :user, TrialApp.Accounts.User
    belongs_to :manager, TrialApp.Accounts.User

    has_many :teams, TrialApp.Orgs.Team
    has_many :employees, TrialApp.Orgs.Employee
    # has_many :positions, TrialApp.Orgs.Position  # Commented out since Position schema doesn't exist

    timestamps()
  end

  @doc """
  Standard changeset for department operations.
  """
  def changeset(department, attrs) do
    department
    |> cast(attrs, [:name, :description, :code, :is_active, :organization_id, :user_id, :manager_id])
    |> validate_required([:name, :organization_id])
    |> validate_length(:code, min: 2, max: 10)
    |> assoc_constraint(:organization)
    |> unique_constraint(:name, name: :departments_name_organization_id_index)
  end

  @doc """
  Changeset for creating a new department with additional validations.
  """
  def create_changeset(department, attrs) do
    department
    |> changeset(attrs)
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/,
      message: "must contain only uppercase letters, numbers, and underscores")
  end

  @doc """
  Returns a department with all relationships preloaded.
  """
  def with_preloads(department) do
    TrialApp.Repo.preload(department, [
      :organization,
      :teams,
      :employees
    ])
  end
end
