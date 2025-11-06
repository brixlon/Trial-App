defmodule TrialApp.Eams.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending in_progress submitted completed rejected)

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :due_on, :date
    field :reject_reason, :string
    field :submitted_at, :utc_datetime

    belongs_to :project, TrialApp.Eams.Project
    belongs_to :assignee, TrialApp.Eams.Attachee

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :title,
      :description,
      :status,
      :due_on,
      :project_id,
      :assignee_id,
      :reject_reason,
      :submitted_at
    ])
    |> validate_required([:title, :project_id, :assignee_id])
    |> validate_inclusion(:status, @statuses)
    |> clear_reject_reason_on_submit()
    |> assoc_constraint(:project)
    |> assoc_constraint(:assignee)
  end

  defp clear_reject_reason_on_submit(changeset) do
    if get_change(changeset, :status) == "submitted" do
      put_change(changeset, :reject_reason, nil)
    else
      changeset
    end
  end

  def create_changeset(task, attrs), do: changeset(task, attrs)
  def update_changeset(task, attrs), do: changeset(task, attrs)
end
