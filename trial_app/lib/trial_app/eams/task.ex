defmodule TrialApp.Eams.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending in_progress blocked completed cancelled)

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
    |> validate_required([:title, :project_id, :assignee_id])
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:project)
    |> assoc_constraint(:assignee)
  end

  def create_changeset(task, attrs), do: changeset(task, attrs)
  def update_changeset(task, attrs), do: changeset(task, attrs)
end
