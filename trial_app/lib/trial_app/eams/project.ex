defmodule TrialApp.Eams.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :description, :string
    field :code, :string
    field :is_active, :boolean, default: true
    field :starts_on, :date
    field :ends_on, :date

    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :program, TrialApp.Eams.Program
    belongs_to :supervisor, TrialApp.Accounts.User

    has_many :tasks, TrialApp.Eams.Task

    # NEW ASSOCIATIONS - Add these lines
    many_to_many :attachees, TrialApp.Eams.Attachee,
      join_through: "project_attachees",
      on_replace: :delete

    has_many :project_attachees, TrialApp.Eams.ProjectAttachee

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :description,
      :code,
      :is_active,
      :starts_on,
      :ends_on,
      :organization_id,
      :department_id,
      :program_id,
      :supervisor_id
    ])
    |> validate_required([:name, :organization_id, :department_id, :program_id])
    |> validate_length(:code, min: 2, max: 16)
    |> validate_date_range()
    |> assoc_constraint(:organization)
    |> assoc_constraint(:department)
    |> assoc_constraint(:program)
    |> assoc_constraint(:supervisor)
    |> unique_constraint(:name, name: :projects_name_program_id_index)
  end

  def create_changeset(project, attrs) do
    project
    |> changeset(attrs)
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/, message: "must be UPPER_SNAKE_CASE")
  end

  def update_changeset(project, attrs), do: changeset(project, attrs)

  defp validate_date_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    cond do
      is_nil(starts_on) or is_nil(ends_on) ->
        changeset

      Date.compare(ends_on, starts_on) == :lt ->
        add_error(changeset, :ends_on, "must be after start date")

      true ->
        changeset
    end
  end
end
