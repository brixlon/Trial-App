defmodule TrialApp.Approval.UserApproval do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_approvals" do
    field :user_id, :integer
    field :approved, :boolean, default: false
    field :approved_at, :utc_datetime
    # Add any other fields you need

    timestamps()
  end

  @doc false
  def changeset(user_approval, attrs, _scope \\ nil) do
    user_approval
    |> cast(attrs, [:user_id, :approved, :approved_at])
    |> validate_required([:user_id])
  end
end
