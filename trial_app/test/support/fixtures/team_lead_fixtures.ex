defmodule TrialApp.TeamLeadFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TrialApp.TeamLead` context.
  """

  @doc """
  Generate a daily_report.
  """
  def daily_report_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        challenges: "some challenges",
        next_day_plans: "some next_day_plans",
        report_date: ~D[2025-11-08],
        status: "some status",
        summary: "some summary",
        tasks_completed: "some tasks_completed"
      })

    {:ok, daily_report} = TrialApp.TeamLead.create_daily_report(scope, attrs)
    daily_report
  end
end
