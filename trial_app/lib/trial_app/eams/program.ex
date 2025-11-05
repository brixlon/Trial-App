defmodule TrialApp.Eams.Program do
  use Ecto.Schema
  import Ecto.Changeset

  schema "programs" do
    field :name, :string
    field :description, :string
    field :code, :string
    field :is_active, :boolean, default: true
    field :starts_on, :date
    field :ends_on, :date
    field :status, :string, default: "active"

    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :department, TrialApp.Orgs.Department

    has_many :projects, TrialApp.Eams.Project

    timestamps()
  end

  def changeset(program, attrs) do
    program
    |> cast(attrs, [:name, :description, :code, :is_active, :starts_on, :ends_on, :status, :organization_id, :department_id])
    |> validate_required([:name, :organization_id, :department_id])
    |> validate_length(:code, min: 2, max: 16)
    |> validate_inclusion(:status, ["active", "inactive", "archived"])
    |> validate_date_range()
    |> assoc_constraint(:organization)
    |> assoc_constraint(:department)
    |> unique_constraint(:name, name: :programs_name_department_id_index)
  end

  def create_changeset(program, attrs) do
    program
    |> changeset(attrs)
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/, message: "must be UPPER_SNAKE_CASE")
  end

  def update_changeset(program, attrs), do: changeset(program, attrs)

  defp validate_date_range(changeset) do
    s = get_field(changeset, :starts_on)
    e = get_field(changeset, :ends_on)
    case {s, e} do
      {nil, _} -> changeset
      {_, nil} -> changeset
      {s, e} when e < s -> add_error(changeset, :ends_on, "must be on or after start date")
      _ -> changeset
    end
  end
end
