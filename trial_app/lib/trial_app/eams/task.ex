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

    # New fields for submission
    field :submission_comment, :string
    field :submission_links, {:array, :string}, default: []
    field :submission_files, {:array, :string}, default: []

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
      :submitted_at,
      :submission_comment,
      :submission_links,
      :submission_files
    ])
    |> validate_required([:title, :project_id, :assignee_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_urls(:submission_links)
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

  defp validate_urls(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      urls when is_list(urls) ->
        if Enum.all?(urls, &valid_url?/1) do
          changeset
        else
          add_error(changeset, field, "contains invalid URLs")
        end

      _ ->
        changeset
    end
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] && uri.host != nil
  end
  defp valid_url?(_), do: false

  def create_changeset(task, attrs), do: changeset(task, attrs)
  def update_changeset(task, attrs), do: changeset(task, attrs)
end
