defmodule TrialApp.Orgs.DailyReport do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft submitted reviewed)

  schema "daily_reports" do
    field :report_date, :date
    field :summary, :string
    field :tasks_completed, :string
    field :challenges, :string
    field :next_day_plans, :string
    field :status, :string, default: "draft"

    belongs_to :team_lead, TrialApp.Accounts.User
    belongs_to :team, TrialApp.Orgs.Team
    belongs_to :supervisor, TrialApp.Accounts.User
    belongs_to :department, TrialApp.Orgs.Department

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :report_date,
      :summary,
      :tasks_completed,
      :challenges,
      :next_day_plans,
      :status,
      :team_lead_id,
      :team_id,
      :supervisor_id,
      :department_id
    ])
    |> validate_required([:report_date, :team_lead_id, :team_id, :supervisor_id, :department_id])
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:team_lead)
    |> assoc_constraint(:team)
    |> assoc_constraint(:supervisor)
    |> assoc_constraint(:department)
    |> unique_constraint([:team_lead_id, :team_id, :report_date],
      name: :daily_reports_team_lead_team_date_index
    )
  end

  def create_changeset(report, attrs), do: changeset(report, attrs)
  def update_changeset(report, attrs), do: changeset(report, attrs)
end

