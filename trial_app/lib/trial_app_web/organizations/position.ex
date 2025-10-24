defmodule TrialApp.Organizations.Position do
  use Ecto.Schema
  import Ecto.Changeset

  schema "positions" do
    field :title, :string
    field :description, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(position, attrs, user_scope) do
    position
    |> cast(attrs, [:title, :description])
    |> validate_required([:title, :description])
    |> put_change(:user_id, user_scope.user.id)
  end
end
