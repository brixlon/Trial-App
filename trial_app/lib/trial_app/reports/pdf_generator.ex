defmodule TrialApp.Reports.PDFGenerator do
  @moduledoc """
  Generates beautiful PDF reports using pdf_generator (wkhtmltopdf).
  """
  require Logger

  # --- 1. THE ADAPTER ---
  def generate_pdf(report, assigns, options, file_path) do
    attachee = assigns.attachee

    # DEBUG LOGS (Optional but helpful)
    Logger.info("=== PDF GENERATOR DEBUG ===")
    Logger.info("Attachee: #{attachee.id}")
    Logger.info("Tasks received: #{length(Map.get(assigns, :attachee_tasks, []))}")
    Logger.info("Evaluations received: #{length(Map.get(assigns, :general_evaluations, []))}")

    report_data = %{
      attachee: attachee,
      organization: attachee.organization,
      department: attachee.department,
      stats: Map.get(assigns, :attachee_stats, %{}),
      tasks: Map.get(assigns, :attachee_tasks, []),
      task_scores: Map.get(assigns, :task_scores, %{}),
      evaluations: Map.get(assigns, :general_evaluations, []),
      projects: Map.get(assigns, :attachee_projects, []), # Include projects
      custom_comments: Map.get(options, :custom_comments, ""),
      # Pass include flags
      include_tasks: Map.get(options, :include_tasks, true),
      include_evaluations: Map.get(options, :include_evaluations, true),
      include_projects: Map.get(options, :include_projects, true),
      include_stats: Map.get(options, :include_stats, true),
      period_start: report.period_start,
      period_end: report.period_end
    }

    generate_pdf_from_html(report, report_data, file_path)
  end

  # --- 2. MAIN LOGIC ---
  def generate_pdf_from_html(report, report_data, file_path) do
    html = render_report_html(report, report_data)

    options = [
      page_size: "A4",
      margin_top: "10mm",
      margin_bottom: "10mm",
      margin_left: "10mm",
      margin_right: "10mm",
      footer_html: footer_html(),
      disable_smart_shrinking: true
    ]

    # FIX: Use generate_binary directly. It handles temp files internally.
    case PdfGenerator.generate_binary(html, options) do
      {:ok, pdf_binary} ->
        File.write!(file_path, pdf_binary)
        Logger.info("PDF generated successfully: #{file_path}")
        {:ok, file_path}

      # Fallback pattern for some library versions that return 3 elements
      {:ok, _filename, pdf_binary} when is_binary(pdf_binary) ->
         File.write!(file_path, pdf_binary)
         Logger.info("PDF generated successfully (tuple match): #{file_path}")
         {:ok, file_path}

      {:error, reason} ->
        Logger.error("PDF Generation failed: #{inspect(reason)}")
        {:error, "Failed to generate PDF: #{inspect(reason)}"}

      # CATCH-ALL: Log exactly what we got so we don't crash with "Unknown"
      unexpected ->
        Logger.error("Unknown PDF Generator return format: #{inspect(unexpected)}")
        {:error, "Unknown PDF generation error (Check server logs)"}
    end
  end

  defp render_report_html(report, data) do
    title = case report.report_type do
      "evaluation_summary" -> "EVALUATION SUMMARY REPORT"
      "monthly_report" -> "MONTHLY PERFORMANCE REPORT"
      "final_report" -> "FINAL ATTACHMENT REPORT"
      _ -> "ATTACHEE PERFORMANCE REPORT"
    end

    # --- Robust Name Display ---
    user = data.attachee.user
    attachee_name =
      cond do
        user.first_name && user.last_name -> "#{user.first_name} #{user.last_name}"
        user.username -> user.username
        true -> user.email
      end

    attachee_email = user.email
    dept_name = if data.department, do: data.department.name, else: "—"
    org_name = if data.organization, do: data.organization.name, else: "Organization"
    position = data.attachee.position || "Industrial Attachee"

    start_date = format_date(data.attachee.starts_on)
    end_date = format_date(data.attachee.ends_on)
    period_start = format_date(report.period_start)
    period_end = format_date(report.period_end)

    # --- Dynamic Stats Calculation ---
    # Filter by period if needed
    filtered_tasks = filter_by_period(data.tasks, data.period_start, data.period_end)
    filtered_evals = filter_evaluations_by_period(data.evaluations, data.period_start, data.period_end)

    total_tasks = length(filtered_tasks)
    completed_count = Enum.count(filtered_tasks, &(&1.status == "completed"))
    comp_rate =
      if total_tasks > 0 do
        Float.round(completed_count * 100.0 / total_tasks, 1)
      else
        0.0
      end

    eval_count = length(filtered_evals)
    avg_score =
      if eval_count > 0 do
        total_score = Enum.reduce(filtered_evals, 0, fn e, acc -> (e.score || 0) + acc end)
        Float.round(total_score / eval_count, 1)
      else
        0.0
      end

    # Generate sections based on flags
    stats_html = if data.include_stats, do: performance_summary_html(avg_score, eval_count, total_tasks, comp_rate), else: ""
    tasks_html = if data.include_tasks, do: task_performance_html(filtered_tasks, data.task_scores), else: ""
    eval_html = if data.include_evaluations, do: evaluation_history_html(filtered_evals), else: ""
    projects_html = if data.include_projects && length(data.projects) > 0, do: projects_section_html(data.projects), else: ""
    comments_html = supervisor_comments_html(data.custom_comments)

    now = format_datetime(DateTime.utc_now())

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>#{title}</title>
      <style>
        #{pdf_styles()}
      </style>
    </head>
    <body>
      <div class="header">
        <h1>#{org_name}</h1>
        <p>Attachment Management System</p>
      </div>

      <div class="report-title">
        <h2>#{title}</h2>
        <div class="period">Period: #{period_start} – #{period_end}</div>
      </div>

      <h2>Attachee Information</h2>
      <div class="info-grid">
        <div class="info-label">Full Name</div>
        <div class="info-value">#{attachee_name}</div>

        <div class="info-label">Email</div>
        <div class="info-value">#{attachee_email}</div>

        <div class="info-label">Department</div>
        <div class="info-value">#{dept_name}</div>

        <div class="info-label">Position</div>
        <div class="info-value">#{position}</div>

        <div class="info-label">Duration</div>
        <div class="info-value">#{start_date} – #{end_date}</div>
      </div>

      #{stats_html}
      #{projects_html}
      #{tasks_html}
      #{eval_html}
      #{comments_html}

      <div class="footer">
        <p><strong>Report generated on:</strong> #{now} UTC</p>
        <p>This is a system-generated confidential report • For internal use only</p>
      </div>
    </body>
    </html>
    """
  end

  # --- FILTERING HELPERS ---
  defp filter_by_period(tasks, period_start, period_end) do
    Enum.filter(tasks, fn task ->
      task_date = extract_date(task.inserted_at)
      if task_date do
        Date.compare(task_date, period_start) != :lt and Date.compare(task_date, period_end) != :gt
      else
        true
      end
    end)
  end

  defp filter_evaluations_by_period(evaluations, period_start, period_end) do
    Enum.filter(evaluations, fn eval ->
      eval_date = extract_date(eval.inserted_at)
      if eval_date do
        Date.compare(eval_date, period_start) != :lt and Date.compare(eval_date, period_end) != :gt
      else
        true
      end
    end)
  end

  defp extract_date(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt)
  defp extract_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp extract_date(%Date{} = d), do: d
  defp extract_date(_), do: nil

  # --- STYLES & HTML HELPERS ---
  defp pdf_styles do
    """
    @page { margin: 0; size: A4; }
    body { font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 11pt; line-height: 1.5; color: #2d3748; margin: 0; padding: 30px; background: white; }
    h1 { color: #5b21b6; font-size: 28pt; margin: 0; text-align: center; }
    h2 { color: #4c1d95; font-size: 18pt; border-bottom: 3px solid #c4b5fd; padding-bottom: 8px; margin: 30px 0 15px; }
    .header { text-align: center; padding-bottom: 20px; border-bottom: 4px double #a78bfa; margin-bottom: 30px; }
    .report-title { background: linear-gradient(90deg, #a78bfa, #c4b5fd); color: white; padding: 20px; border-radius: 10px; text-align: center; margin: 20px 0; }
    .period { font-size: 12pt; opacity: 0.9; }
    .info-grid { display: grid; grid-template-columns: 1fr 2fr; gap: 8px 15px; background: #f8fafc; padding: 15px; border-radius: 8px; margin: 15px 0; font-size: 11pt; }
    .info-label { font-weight: bold; color: #4c1d95; }
    .info-value { color: #1f2937; }
    .stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; margin: 20px 0; }
    .stat-card { background: white; padding: 15px; border-radius: 10px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; }
    .stat-card.main { background: #5b21b6; color: white; }
    .stat-value { font-size: 24pt; font-weight: bold; display: block; }
    .stat-label { font-size: 8pt; text-transform: uppercase; letter-spacing: 1px; opacity: 0.9; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; background: white; }
    th { background: #f1f5f9; color: #475569; padding: 12px; text-transform: uppercase; font-size: 9pt; text-align: left; }
    td { padding: 12px; border-bottom: 1px solid #e2e8f0; }
    tr:hover { background: #f8fafc; }
    .badge { padding: 4px 10px; border-radius: 20px; font-size: 9pt; font-weight: bold; display: inline-block; }
    .excellent { background: #dcfce7; color: #166534; }
    .good { background: #dbeafe; color: #1e40af; }
    .satisfactory { background: #fef3c7; color: #92400e; }
    .poor { background: #fee2e2; color: #991b1b; }
    .pending { background: #f3f4f6; color: #6b7280; }
    .completed { background: #dcfce7; color: #166534; }
    .in_progress { background: #dbeafe; color: #1e40af; }
    .rejected { background: #fee2e2; color: #991b1b; }
    .submitted { background: #e0e7ff; color: #3730a3; }
    .eval-card { background: #f8fafc; border-left: 5px solid #7c3aed; padding: 15px; border-radius: 0 8px 8px 0; margin: 12px 0; }
    .eval-score { float: right; background: #7c3aed; color: white; width: 50px; height: 50px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 16pt; font-weight: bold; }
    .comments { font-style: italic; color: #64748b; margin-top: 10px; }
    .footer { margin-top: 50px; padding-top: 20px; border-top: 2px solid #e2e8f0; text-align: center; color: #94a3b8; font-size: 9pt; }
    .project-item { background: #f8fafc; padding: 12px; margin: 8px 0; border-radius: 6px; border-left: 4px solid #7c3aed; }
    """
  end

  defp performance_summary_html(avg_score, eval_count, total_tasks, comp_rate) do
    """
    <h2>Performance Summary</h2>
    <div class="stats-grid">
      <div class="stat-card main">
        <span class="stat-value">#{avg_score}</span>
        <span class="stat-label">Average Score</span>
      </div>
      <div class="stat-card">
        <span class="stat-value">#{eval_count}</span>
        <span class="stat-label">Evaluations</span>
      </div>
      <div class="stat-card">
        <span class="stat-value">#{total_tasks}</span>
        <span class="stat-label">Total Tasks</span>
      </div>
      <div class="stat-card">
        <span class="stat-value">#{comp_rate}%</span>
        <span class="stat-label">Completion</span>
      </div>
    </div>
    """
  end

  defp projects_section_html(projects) do
    items = Enum.map(projects, fn proj ->
      program_name = if proj.program, do: proj.program.name, else: "N/A"
      """
      <div class="project-item">
        <strong>#{safe_html(proj.name)}</strong><br>
        <span style="color: #64748b; font-size: 10pt;">Program: #{safe_html(program_name)}</span>
      </div>
      """
    end)
    |> Enum.join()

    """
    <h2>Projects Assigned</h2>
    #{items}
    """
  end

  defp task_performance_html(tasks, task_scores) do
    rows = if Enum.empty?(tasks) do
      """
      <tr><td colspan="4" style="text-align:center; color:#94a3b8; padding:20px;">No tasks assigned during this period</td></tr>
      """
    else
      Enum.map(tasks, fn task ->
        score_info = Map.get(task_scores, task.id)
        score = if score_info, do: score_info.score, else: nil
        level_class = if score, do: score_to_level(score), else: "pending"
        level_label = if score, do: score_to_label(score), else: "Pending"

        # Safe Title Access
        task_title = Map.get(task, :title) || "Task ##{task.id}"

        status_display = task.status |> to_string() |> String.replace("_", " ") |> String.capitalize()
        status_class = task.status

        """
        <tr>
          <td>#{safe_html(task_title)}</td>
          <td><span class="badge #{status_class}">#{status_display}</span></td>
          <td>#{if score, do: "#{score}/100", else: "—"}</td>
          <td><span class="badge #{level_class}">#{level_label}</span></td>
        </tr>
        """
      end)
      |> Enum.join()
    end

    """
    <h2>Task Performance</h2>
    <table>
      <thead>
        <tr>
          <th>Task</th>
          <th>Status</th>
          <th>Score</th>
          <th>Performance</th>
        </tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    """
  end

  defp evaluation_history_html(evaluations) do
    cards = if Enum.empty?(evaluations) do
      """
      <p style="color:#94a3b8; text-align:center; padding:30px;">No evaluations recorded during this period.</p>
      """
    else
      evaluations
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(10)
      |> Enum.map(fn e ->
        name = if e.evaluator, do: e.evaluator.username || e.evaluator.email, else: "System"

        comments_html = if e.comments && e.comments != "" do
          """
          <div class="comments">"#{safe_html(e.comments)}"</div>
          """
        else
          ""
        end

        """
        <div class="eval-card">
          <div class="eval-score">#{e.score}</div>
          <strong>#{safe_html(name)}</strong> • #{format_datetime(e.inserted_at)}<br>
          <em>Score: #{e.score}/100 – #{score_to_label(e.score)}</em>
          #{comments_html}
        </div>
        """
      end)
      |> Enum.join()
    end

    """
    <h2>Recent Evaluations</h2>
    #{cards}
    """
  end

  defp supervisor_comments_html(comments) do
    text = if comments && comments != "", do: format_comments(comments), else: "No additional comments provided."

    """
    <h2>Supervisor Comments</h2>
    <div style="background:#f8fafc; padding:20px; border-radius:8px; border-left:5px solid #7c3aed;">
      #{text}
    </div>
    """
  end

  defp footer_html do
    """
    <div style="text-align:center; font-size:9pt; color:#94a3b8; width:100%;">
      Page <span class="pageNumber"></span> of <span class="totalPages"></span> • Confidential Report
    </div>
    """
  end

  defp safe_html(nil), do: ""
  defp safe_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
  defp safe_html(text), do: to_string(text)

  defp score_to_level(score) when score >= 81, do: "excellent"
  defp score_to_level(score) when score >= 61, do: "good"
  defp score_to_level(score) when score >= 41, do: "satisfactory"
  defp score_to_level(_), do: "poor"

  defp score_to_label(score) when score >= 81, do: "Excellent"
  defp score_to_label(score) when score >= 61, do: "Good"
  defp score_to_label(score) when score >= 41, do: "Satisfactory"
  defp score_to_label(_), do: "Needs Improvement"

  defp format_date(nil), do: "N/A"
  defp format_date(date), do: Calendar.strftime(date, "%B %d, %Y")

  defp format_datetime(dt), do: Calendar.strftime(dt, "%B %d, %Y at %H:%M")

  defp format_comments(text) do
    text
    |> safe_html()
    |> String.replace("\n", "<br>")
  end
end
