defmodule TrialApp.Eams.Evaluation do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Eams.Attachee
  alias TrialApp.Accounts.User
  alias TrialApp.Eams.Task

  schema "evaluations" do
    field :score, :integer
    field :comments, :string
    field :user_id, :id

    belongs_to :attachee, Attachee
    belongs_to :evaluator, User, foreign_key: :evaluator_id
    belongs_to :task, Task
    timestamps(type: :utc_datetime)
  end

  @doc false
 def changeset(evaluation, attrs, user_scope) do
  evaluation
  |> cast(attrs, [:score, :comments, :attachee_id, :evaluator_id, :task_id])  # Added :task_id here!
  |> validate_required([:score, :comments, :attachee_id, :evaluator_id])
  |> validate_number(:score, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
  |> validate_length(:comments, min: 10, max: 1000)
  |> put_change(:user_id, user_scope.id)
  |> foreign_key_constraint(:attachee_id)
  |> foreign_key_constraint(:evaluator_id)
  |> foreign_key_constraint(:user_id)
  |> foreign_key_constraint(:task_id)
end
end
