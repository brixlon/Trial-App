defmodule TrialApp.Orgs.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :name, :string
    field :..., :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(employee, attrs, user_scope) do
    employee
    |> cast(attrs, [:name, :...])
    |> validate_required([:name, :...])
    |> put_change(:user_id, user_scope.user.id)
  end
end
