defmodule TrialApp.Reports.ReportHTMLTest do
  use ExUnit.Case, async: true
  alias TrialApp.Reports.ReportHTML

  test "renders report structure" do
    assigns = %{
      title: "Test Report",
      css: "body { color: red; }",
      organization: %{name: "Acme Corp"},
      period_start: ~D[2023-01-01],
      period_end: ~D[2023-01-31],
      attachee: %{
        user: %{email: "test@example.com", first_name: "John", last_name: "Doe"},
        position: "Intern",
        starts_on: ~D[2023-01-01],
        ends_on: ~D[2023-06-01]
      },
      department: %{name: "Engineering"},
      attachee_name: "John Doe",
      include_stats: true,
      avg_score: 85.5,
      eval_count: 2,
      total_tasks: 5,
      comp_rate: 80.0,
      include_projects: true,
      projects: [%{name: "Project A", code: "P-01"}],
      include_tasks: true,
      tasks: [%{id: 1, title: "Task 1", status: "completed"}],
      task_scores: %{1 => %{score: 90}},
      monthly_tasks: [
        {1,
         [
           %{
             id: 1,
             title: "Task 1",
             status: "completed",
             rating: "meets_expectations",
             rating_comment: "Good work"
           }
         ]}
      ],
      month_1_score: 85,
      month_2_score: 0,
      month_3_score: 0,
      total_score: 85,
      include_evaluations: true,
      filtered_evals: [
        %{
          evaluator: %{username: "Supervisor"},
          inserted_at: ~N[2023-01-15 10:00:00],
          score: 85,
          comments: "Good job"
        }
      ],
      custom_comments: "Keep it up",
      comments: "Keep it up"
    }

    html = Phoenix.Template.render_to_string(ReportHTML, "report", "html", assigns)

    assert html =~ "Test Report"
    assert html =~ "Acme Corp"
    assert html =~ "John Doe"
    assert html =~ "85.5"
    assert html =~ "Project A"
    assert html =~ "Task 1"
    assert html =~ "Keep it up"
  end
end
