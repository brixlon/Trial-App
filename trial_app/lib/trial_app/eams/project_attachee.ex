defmodule TrialApp.Eams.ProjectAttachee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_attachees" do
    field :role, :string
    field :joined_at, :date
    field :left_at, :date

    belongs_to :project, TrialApp.Eams.Project
    belongs_to :attachee, TrialApp.Eams.Attachee

    timestamps()
  end

  def changeset(project_attachee, attrs) do
    project_attachee
    |> cast(attrs, [:role, :joined_at, :left_at, :project_id, :attachee_id])
    |> validate_required([:project_id, :attachee_id])
    |> validate_dates()
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:attachee_id)
    |> unique_constraint([:project_id, :attachee_id],
      message: "Attachee is already assigned to this project"
    )
  end

  defp validate_dates(changeset) do
    joined_at = get_field(changeset, :joined_at)
    left_at = get_field(changeset, :left_at)

    if joined_at && left_at && Date.compare(left_at, joined_at) == :lt do
      add_error(changeset, :left_at, "must be after joined date")
    else
      changeset
    end
  end
end
