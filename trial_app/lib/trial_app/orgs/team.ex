defmodule TrialApp.Orgs.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @team_types ~w(general project functional support operations sales engineering marketing)

  schema "teams" do
    field :name, :string
    field :description, :string
    field :code, :string
    field :is_active, :boolean, default: true
    field :team_type, :string, default: "general"

    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :team_lead, TrialApp.Accounts.User

    has_many :employees, TrialApp.Orgs.Employee

    timestamps()
  end

  @doc """
  Standard changeset for team operations.
  """
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :code, :is_active, :team_type, :department_id, :organization_id, :team_lead_id])
    |> validate_required([:name, :department_id, :organization_id])
    |> validate_length(:code, min: 2, max: 10)
    |> validate_inclusion(:team_type, @team_types)
    |> assoc_constraint(:department)
    |> assoc_constraint(:organization)
    |> assoc_constraint(:team_lead)
    |> validate_organization_department_consistency()
    |> unique_constraint(:name, name: :teams_name_department_id_index)
  end

  @doc """
  Changeset for creating a new team with additional validations.
  """
  def create_changeset(team, attrs) do
    team
    |> changeset(attrs)
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/,
      message: "must contain only uppercase letters, numbers, and underscores")
  end

  defp validate_organization_department_consistency(changeset) do
    department_id = get_field(changeset, :department_id)
    organization_id = get_field(changeset, :organization_id)

    if department_id && organization_id do
      department = TrialApp.Repo.get(TrialApp.Orgs.Department, department_id)
      if department && department.organization_id != organization_id do
        add_error(changeset, :department_id, "must belong to the selected organization")
      else
        changeset
      end
    else
      changeset
    end
  end

  @doc """
  Returns a team with all relationships preloaded.
  """
  def with_preloads(team) do
    TrialApp.Repo.preload(team, [
      :department,
      :organization,
      :team_lead,
      :employees
    ])
  end
end
