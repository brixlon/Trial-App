defmodule TrialApp.Eams.Evaluation do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Eams.Attachee
  alias TrialApp.Accounts.User
  alias TrialApp.Eams.Task

  schema "evaluations" do
    field :score, :integer
    field :comments, :string
    field :evaluation_details, :string

    field :evaluation_period_start, :date
    field :evaluation_period_end, :date
    field :is_final, :boolean, default: false

    # Monthly breakdown
    field :month_1_score, :integer
    field :month_2_score, :integer
    field :month_3_score, :integer
    field :month_1_tasks_count, :integer, default: 0
    field :month_2_tasks_count, :integer, default: 0
    field :month_3_tasks_count, :integer, default: 0

    belongs_to :attachee, Attachee
    belongs_to :evaluator, User, foreign_key: :evaluator_id
    belongs_to :task, Task
    field :user_id, :integer
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(evaluation, attrs, user_scope) do
    evaluation
    |> cast(attrs, [
      :score,
      :comments,
      :evaluation_details,
      :attachee_id,
      :evaluator_id,
      :task_id,
      :evaluation_period_start,
      :evaluation_period_end,
      :is_final,
      :month_1_score,
      :month_2_score,
      :month_3_score,
      :month_1_tasks_count,
      :month_2_tasks_count,
      :month_3_tasks_count
    ])
    |> validate_required([:score, :comments, :attachee_id, :evaluator_id])
    |> validate_number(:score, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
    |> validate_length(:comments, min: 10, max: 1000)
    |> put_change(:user_id, user_scope.id)
    |> foreign_key_constraint(:attachee_id)
    |> foreign_key_constraint(:evaluator_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:task_id)
    |> unique_constraint([:attachee_id, :evaluation_period_start, :evaluation_period_end],
      name: :evaluations_attachee_period_unique_index,
      message: "Evaluation already exists for this period"
    )
  end

  def calculate_monthly_scores(evaluation, _tasks, _attachee_start_date) do
    # Logic to calculate scores based on task dates relative to start date
    # This will be called before saving the evaluation
    evaluation
  end
end
