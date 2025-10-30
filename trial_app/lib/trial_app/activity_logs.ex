defmodule TrialApp.ActivityLogs do
  import Ecto.Query
  alias TrialApp.{Repo, ActivityLog}

  def log_activity(actor_id, message, meta \\ %{})
  def log_activity(nil, message, meta), do: %ActivityLog{} |> ActivityLog.changeset(%{message: message, meta: meta}) |> Repo.insert()
  def log_activity(actor_id, message, meta), do: %ActivityLog{} |> ActivityLog.changeset(%{actor_id: actor_id, message: message, meta: meta}) |> Repo.insert()

  def list_recent_activity(limit \\ 20) do
    ActivityLog
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> preload(:actor)
    |> Repo.all()
  end
end
