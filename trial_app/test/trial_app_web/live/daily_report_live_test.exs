defmodule TrialAppWeb.DailyReportLiveTest do
  use TrialAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrialApp.TeamLeadFixtures

  @create_attrs %{status: "some status", report_date: "2025-11-08", summary: "some summary", tasks_completed: "some tasks_completed", challenges: "some challenges", next_day_plans: "some next_day_plans"}
  @update_attrs %{status: "some updated status", report_date: "2025-11-09", summary: "some updated summary", tasks_completed: "some updated tasks_completed", challenges: "some updated challenges", next_day_plans: "some updated next_day_plans"}
  @invalid_attrs %{status: nil, report_date: nil, summary: nil, tasks_completed: nil, challenges: nil, next_day_plans: nil}

  setup :register_and_log_in_user

  defp create_daily_report(%{scope: scope}) do
    daily_report = daily_report_fixture(scope)

    %{daily_report: daily_report}
  end

  describe "Index" do
    setup [:create_daily_report]

    test "lists all daily_reports", %{conn: conn, daily_report: daily_report} do
      {:ok, _index_live, html} = live(conn, ~p"/daily_reports")

      assert html =~ "Listing Daily reports"
      assert html =~ daily_report.summary
    end

    test "saves new daily_report", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/daily_reports")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Daily report")
               |> render_click()
               |> follow_redirect(conn, ~p"/daily_reports/new")

      assert render(form_live) =~ "New Daily report"

      assert form_live
             |> form("#daily_report-form", daily_report: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#daily_report-form", daily_report: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/daily_reports")

      html = render(index_live)
      assert html =~ "Daily report created successfully"
      assert html =~ "some summary"
    end

    test "updates daily_report in listing", %{conn: conn, daily_report: daily_report} do
      {:ok, index_live, _html} = live(conn, ~p"/daily_reports")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#daily_reports-#{daily_report.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/daily_reports/#{daily_report}/edit")

      assert render(form_live) =~ "Edit Daily report"

      assert form_live
             |> form("#daily_report-form", daily_report: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#daily_report-form", daily_report: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/daily_reports")

      html = render(index_live)
      assert html =~ "Daily report updated successfully"
      assert html =~ "some updated summary"
    end

    test "deletes daily_report in listing", %{conn: conn, daily_report: daily_report} do
      {:ok, index_live, _html} = live(conn, ~p"/daily_reports")

      assert index_live |> element("#daily_reports-#{daily_report.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#daily_reports-#{daily_report.id}")
    end
  end

  describe "Show" do
    setup [:create_daily_report]

    test "displays daily_report", %{conn: conn, daily_report: daily_report} do
      {:ok, _show_live, html} = live(conn, ~p"/daily_reports/#{daily_report}")

      assert html =~ "Show Daily report"
      assert html =~ daily_report.summary
    end

    test "updates daily_report and returns to show", %{conn: conn, daily_report: daily_report} do
      {:ok, show_live, _html} = live(conn, ~p"/daily_reports/#{daily_report}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/daily_reports/#{daily_report}/edit?return_to=show")

      assert render(form_live) =~ "Edit Daily report"

      assert form_live
             |> form("#daily_report-form", daily_report: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#daily_report-form", daily_report: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/daily_reports/#{daily_report}")

      html = render(show_live)
      assert html =~ "Daily report updated successfully"
      assert html =~ "some updated summary"
    end
  end
end
