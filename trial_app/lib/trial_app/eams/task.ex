defmodule TrialApp.Eams.Task do
  use Ecto.Schema
  import Ecto.Changeset
  alias TrialApp.Repo

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
    belongs_to :created_by, TrialApp.Accounts.User, foreign_key: :created_by_id

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
      :created_by_id,
      :reject_reason,
      :submitted_at
    ])
    |> validate_required([:title, :project_id, :assignee_id])
    |> validate_inclusion(:status, @statuses)
    |> clear_reject_reason_on_submit()
    |> validate_task_dates_within_project()
    |> assoc_constraint(:project)
    |> assoc_constraint(:assignee)
    |> assoc_constraint(:created_by)
  end

  defp validate_task_dates_within_project(changeset) do
    due_on = get_change(changeset, :due_on) || get_field(changeset, :due_on)
    project_id = get_change(changeset, :project_id) || get_field(changeset, :project_id)

    if due_on && project_id do
      project = TrialApp.Repo.get(TrialApp.Eams.Project, project_id) |> TrialApp.Repo.preload(:program)

      cond do
        is_nil(project) ->
          changeset

        not is_nil(project.starts_on) and Date.compare(due_on, project.starts_on) == :lt ->
          add_error(changeset, :due_on, "must be on or after project start date")

        not is_nil(project.ends_on) and Date.compare(due_on, project.ends_on) == :gt ->
          add_error(changeset, :due_on, "must be on or before project end date")

        true ->
          changeset
      end
    else
      changeset
    end
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
