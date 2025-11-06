defmodule TrialApp.Eams.Task do
  use Ecto.Schema
  import Ecto.Changeset

  # Use strings, not atoms
  @statuses ~w(pending in_progress blocked submitted completed cancelled)

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :due_on, :date

    belongs_to :project, TrialApp.Eams.Project
    belongs_to :assignee, TrialApp.Eams.Attachee

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :status, :due_on, :project_id, :assignee_id])
    |> validate_required([:title, :project_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:assignee_id)
  end

  def create_changeset(task, attrs) do
    task
    |> changeset(attrs)
    |> validate_required([:assignee_id])
  end
# lib/trial_app/eams/task.ex
def changeset(task, attrs) do
  task
  |> cast(attrs, [:title, :description, :status, :due_on, :project_id, :assignee_id, :reject_reason])
  |> validate_required([:title, :project_id])
  |> validate_inclusion(:status, @statuses)
  |> foreign_key_constraint(:project_id)
  |> foreign_key_constraint(:assignee_id)
end
  def update_changeset(task, attrs) do
    changeset(task, attrs)
  end
end
