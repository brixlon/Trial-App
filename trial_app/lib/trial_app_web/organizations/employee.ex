defmodule TrialApp.Organizations.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :name, :string
    field :email, :string
    field :position, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(employee, attrs, user_scope) do
    employee
    |> cast(attrs, [:name, :email, :position])
    |> validate_required([:name, :email, :position])
    |> put_change(:user_id, user_scope.user.id)
  end
end
