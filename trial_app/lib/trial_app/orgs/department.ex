defmodule TrialApp.Orgs.Department do
  use Ecto.Schema
  import Ecto.Changeset

  schema "departments" do
    field :name, :string
    field :..., :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(department, attrs, user_scope) do
    department
    |> cast(attrs, [:name, :...])
    |> validate_required([:name, :...])
    |> put_change(:user_id, user_scope.user.id)
  end
end
