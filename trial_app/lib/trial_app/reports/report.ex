defmodule TrialApp.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  alias TrialApp.Eams.Attachee
  alias TrialApp.Accounts.User

  @report_types ~w(evaluation_summary monthly_report final_report)
  @statuses ~w(draft generated sent viewed)

  schema "reports" do
    field :report_type, :string
    field :file_path, :string
    field :file_name, :string
    field :period_start, :date
    field :period_end, :date
    field :status, :string, default: "draft"
    field :sent_at, :utc_datetime
    field :viewed_at, :utc_datetime
    field :summary_data, :map, default: %{}

    belongs_to :attachee, Attachee
    belongs_to :generated_by, User, foreign_key: :generated_by_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :report_type,
      :file_path,
      :file_name,
      :period_start,
      :period_end,
      :status,
      :sent_at,
      :viewed_at,
      :summary_data,
      :attachee_id,
      :generated_by_id
    ])
    |> validate_required([:report_type, :attachee_id, :generated_by_id])
    |> validate_inclusion(:report_type, @report_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:attachee_id)
    |> foreign_key_constraint(:generated_by_id)
  end

  @doc "Mark report as generated"
  def generate_changeset(report, file_path, file_name) do
    report
    |> change(%{
      status: "generated",
      file_path: file_path,
      file_name: file_name
    })
  end

  @doc "Mark report as sent"
  def send_changeset(report) do
    report
    |> change(%{status: "sent", sent_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  @doc "Mark report as viewed"
  def view_changeset(report) do
    report
    |> change(%{status: "viewed", viewed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end
end
