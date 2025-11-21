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

    # New fields for submission
    field :submission_comment, :string
    field :submission_links, {:array, :string}, default: []
    field :submission_files, {:array, :string}, default: []

    belongs_to :project, TrialApp.Eams.Project
    belongs_to :assignee, TrialApp.Eams.Attachee

    has_many :task_evaluations, TrialApp.Eams.Evaluation, foreign_key: :task_id

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
      :submitted_at,
      :submission_comment,
      :submission_links,
      :submission_files
    ])
    |> validate_required([:title, :project_id, :assignee_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_urls(:submission_links)
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
