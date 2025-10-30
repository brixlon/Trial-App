defmodule TrialApp.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_logs" do
    field :message, :string
    field :meta, :map
    belongs_to :actor, TrialApp.Accounts.User
    timestamps()
  end

  def changeset(activity_log, attrs) do
    activity_log
    |> cast(attrs, [:actor_id, :message, :meta])
    |> validate_required([:message])
  end
end
