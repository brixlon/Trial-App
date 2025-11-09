defmodule TrialApp.Eams.Project do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias TrialApp.Repo

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
    |> validate_project_dates_within_program()
    |> assoc_constraint(:organization)
    |> assoc_constraint(:department)
    |> assoc_constraint(:program)
    |> assoc_constraint(:supervisor)
    |> unique_constraint(:name, name: :projects_name_program_id_index)
  end

  defp validate_project_dates_within_program(changeset) do
    starts_on = get_change(changeset, :starts_on) || get_field(changeset, :starts_on)
    ends_on = get_change(changeset, :ends_on) || get_field(changeset, :ends_on)
    program_id = get_change(changeset, :program_id) || get_field(changeset, :program_id)

    if program_id && (starts_on || ends_on) do
      program = TrialApp.Repo.get(TrialApp.Eams.Program, program_id)

      cond do
        is_nil(program) ->
          changeset

        not is_nil(starts_on) and not is_nil(program.starts_on) and Date.compare(starts_on, program.starts_on) == :lt ->
          add_error(changeset, :starts_on, "must be on or after program start date")

        not is_nil(ends_on) and not is_nil(program.ends_on) and Date.compare(ends_on, program.ends_on) == :gt ->
          add_error(changeset, :ends_on, "must be on or before program end date")

        true ->
          changeset
      end
    else
      changeset
    end
  end

  def create_changeset(project, attrs) do
    project
    |> changeset(attrs)
    |> validate_format(:code, ~r/^[A-Z0-9_]+$/, message: "must be UPPER_SNAKE_CASE")
  end

  def update_changeset(project, attrs), do: changeset(project, attrs)

  # FIXED: This function now properly validates dates
  defp validate_date_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    cond do
      # If either date is nil, skip validation
      is_nil(starts_on) or is_nil(ends_on) ->
        changeset

      # Only add error if end date is BEFORE start date
      # Using Date.compare/2 for proper date comparison
      Date.compare(ends_on, starts_on) == :lt ->
        add_error(changeset, :ends_on, "must be after start date")

      # All other cases are valid (including when dates are equal or end is after start)
      true ->
        changeset
    end
  end
end
