defmodule TrialApp.TeamLeadTest do
  use TrialApp.DataCase

  alias TrialApp.TeamLead

  describe "daily_reports" do
    alias TrialApp.TeamLead.DailyReport

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.TeamLeadFixtures

    @invalid_attrs %{status: nil, report_date: nil, summary: nil, tasks_completed: nil, challenges: nil, next_day_plans: nil}

    test "list_daily_reports/1 returns all scoped daily_reports" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      other_daily_report = daily_report_fixture(other_scope)
      assert TeamLead.list_daily_reports(scope) == [daily_report]
      assert TeamLead.list_daily_reports(other_scope) == [other_daily_report]
    end

    test "get_daily_report!/2 returns the daily_report with given id" do
      scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      other_scope = user_scope_fixture()
      assert TeamLead.get_daily_report!(scope, daily_report.id) == daily_report
      assert_raise Ecto.NoResultsError, fn -> TeamLead.get_daily_report!(other_scope, daily_report.id) end
    end

    test "create_daily_report/2 with valid data creates a daily_report" do
      valid_attrs = %{status: "some status", report_date: ~D[2025-11-08], summary: "some summary", tasks_completed: "some tasks_completed", challenges: "some challenges", next_day_plans: "some next_day_plans"}
      scope = user_scope_fixture()

      assert {:ok, %DailyReport{} = daily_report} = TeamLead.create_daily_report(scope, valid_attrs)
      assert daily_report.status == "some status"
      assert daily_report.report_date == ~D[2025-11-08]
      assert daily_report.summary == "some summary"
      assert daily_report.tasks_completed == "some tasks_completed"
      assert daily_report.challenges == "some challenges"
      assert daily_report.next_day_plans == "some next_day_plans"
      assert daily_report.user_id == scope.user.id
    end

    test "create_daily_report/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = TeamLead.create_daily_report(scope, @invalid_attrs)
    end

    test "update_daily_report/3 with valid data updates the daily_report" do
      scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      update_attrs = %{status: "some updated status", report_date: ~D[2025-11-09], summary: "some updated summary", tasks_completed: "some updated tasks_completed", challenges: "some updated challenges", next_day_plans: "some updated next_day_plans"}

      assert {:ok, %DailyReport{} = daily_report} = TeamLead.update_daily_report(scope, daily_report, update_attrs)
      assert daily_report.status == "some updated status"
      assert daily_report.report_date == ~D[2025-11-09]
      assert daily_report.summary == "some updated summary"
      assert daily_report.tasks_completed == "some updated tasks_completed"
      assert daily_report.challenges == "some updated challenges"
      assert daily_report.next_day_plans == "some updated next_day_plans"
    end

    test "update_daily_report/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)

      assert_raise MatchError, fn ->
        TeamLead.update_daily_report(other_scope, daily_report, %{})
      end
    end

    test "update_daily_report/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = TeamLead.update_daily_report(scope, daily_report, @invalid_attrs)
      assert daily_report == TeamLead.get_daily_report!(scope, daily_report.id)
    end

    test "delete_daily_report/2 deletes the daily_report" do
      scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      assert {:ok, %DailyReport{}} = TeamLead.delete_daily_report(scope, daily_report)
      assert_raise Ecto.NoResultsError, fn -> TeamLead.get_daily_report!(scope, daily_report.id) end
    end

    test "delete_daily_report/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      assert_raise MatchError, fn -> TeamLead.delete_daily_report(other_scope, daily_report) end
    end

    test "change_daily_report/2 returns a daily_report changeset" do
      scope = user_scope_fixture()
      daily_report = daily_report_fixture(scope)
      assert %Ecto.Changeset{} = TeamLead.change_daily_report(scope, daily_report)
    end
  end
end
