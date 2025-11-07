defmodule TrialApp.Eams.Evaluation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "evaluations" do
    field :score, :integer
    field :comments, :string
    field :attachee_id, :id
    field :evaluator_id, :id
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(evaluation, attrs, user_scope) do
    evaluation
    |> cast(attrs, [:score, :comments])
    |> validate_required([:score, :comments])
    |> put_change(:user_id, user_scope.user.id)
  end
end
