defmodule TrialApp.Reports.PDFGenerator do
  @moduledoc """
  Generates beautiful PDF reports using pdf_generator (wkhtmltopdf).
  """
  require Logger

  # --- 1. THE ADAPTER ---
  def generate_pdf(report, assigns, options, file_path) do
    attachee = assigns.attachee

    # DEBUG LOGS
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
      projects: Map.get(assigns, :attachee_projects, []),
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
      margin_top: "15mm",
      margin_bottom: "15mm",
      margin_left: "15mm",
      margin_right: "15mm",
      footer_html: footer_html(),
      disable_smart_shrinking: true,
      print_media_type: true
    ]

    case PdfGenerator.generate_binary(html, options) do
      {:ok, pdf_binary} ->
        File.write!(file_path, pdf_binary)
        Logger.info("PDF generated successfully: #{file_path}")
        {:ok, file_path}

      {:ok, _filename, pdf_binary} when is_binary(pdf_binary) ->
         File.write!(file_path, pdf_binary)
         Logger.info("PDF generated successfully (tuple match): #{file_path}")
         {:ok, file_path}

      {:error, reason} ->
        Logger.error("PDF Generation failed: #{inspect(reason)}")
        {:error, "Failed to generate PDF: #{inspect(reason)}"}

      unexpected ->
        Logger.error("Unknown PDF Generator return format: #{inspect(unexpected)}")
        {:error, "Unknown PDF generation error (Check server logs)"}
    end
  end

  defp render_report_html(report, data) do
    title = get_report_title(report.report_type)

    # --- Robust Name Display ---
    user = data.attachee.user
    attachee_name =
      cond do
        user.first_name && user.last_name -> "#{user.first_name} #{user.last_name}"
        user.username -> user.username
        true -> user.email
      end

    # --- Dynamic Stats Calculation ---
    filtered_tasks = filter_by_period(data.tasks, data.period_start, data.period_end)
    filtered_evals = filter_evaluations_by_period(data.evaluations, data.period_start, data.period_end)

    total_tasks = length(filtered_tasks)
    completed_count = Enum.count(filtered_tasks, &(&1.status == "completed"))
    comp_rate = if total_tasks > 0, do: Float.round(completed_count * 100.0 / total_tasks, 1), else: 0.0

    eval_count = length(filtered_evals)
    avg_score =
      if eval_count > 0 do
        total = Enum.reduce(filtered_evals, 0, fn e, acc -> (e.score || 0) + acc end)
        Float.round(total / eval_count, 1)
      else
        0.0
      end

    # --- Components ---
    header = component_header(data.organization, title, report.period_start, report.period_end)
    info_grid = component_info_grid(attachee_name, data.attachee, data.department)

    stats_section = if data.include_stats, do: component_stats(avg_score, eval_count, total_tasks, comp_rate), else: ""
    projects_section = if data.include_projects && length(data.projects) > 0, do: component_projects(data.projects), else: ""
    tasks_section = if data.include_tasks, do: component_tasks(filtered_tasks, data.task_scores), else: ""
    evals_section = if data.include_evaluations, do: component_evaluations(filtered_evals), else: ""
    comments_section = component_comments(data.custom_comments)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>#{title}</title>
      <style>#{pdf_styles()}</style>
    </head>
    <body>
      #{header}
      #{info_grid}

      <div class="content-body">
        #{stats_section}
        #{projects_section}
        #{tasks_section}
        #{evals_section}
        #{comments_section}
      </div>
    </body>
    </html>
    """
  end

  # --- COMPONENT FUNCTIONS ---

  defp component_header(org, title, start_date, end_date) do
    org_name = if org, do: org.name, else: "Company Name"

    # LOGO PLACEHOLDER: Replace with <img> tag if you have a file path
    # Example: <img src='file:///absolute/path/to/logo.png' class='logo-img' />
    logo_html = """
    <div class="logo-placeholder">
      #{String.slice(org_name, 0, 2) |> String.upcase()}
    </div>
    """

    """
    <div class="header-container">
      <div class="header-left">
        #{logo_html}
      </div>
      <div class="header-right">
        <h1 class="company-name">#{org_name}</h1>
        <div class="report-meta">
          <h2 class="report-name">#{title}</h2>
          <p class="report-period">Period: #{format_date(start_date)} – #{format_date(end_date)}</p>
        </div>
      </div>
    </div>
    <div class="header-divider"></div>
    """
  end

  defp component_info_grid(name, attachee, department) do
    user = attachee.user
    dept_name = if department, do: department.name, else: "—"
    position = attachee.position || "Industrial Attachee"

    """
    <div class="info-box">
      <table class="info-table">
        <tr>
          <td class="info-label">Attachee Name</td>
          <td class="info-value"><strong>#{name}</strong></td>
          <td class="info-label">Department</td>
          <td class="info-value">#{dept_name}</td>
        </tr>
        <tr>
          <td class="info-label">Email</td>
          <td class="info-value">#{user.email}</td>
          <td class="info-label">Position</td>
          <td class="info-value">#{position}</td>
        </tr>
        <tr>
          <td class="info-label">Attachment Duration</td>
          <td class="info-value" colspan="3">
            #{format_date(attachee.starts_on)} — #{format_date(attachee.ends_on)}
          </td>
        </tr>
      </table>
    </div>
    """
  end

  defp component_stats(avg, evals, tasks, rate) do
    """
    <div class="section-container">
      <h3 class="section-title">Performance Overview</h3>
      <div class="stats-row">
        <div class="stat-item highlight">
          <span class="stat-val">#{avg}</span>
          <span class="stat-lbl">Avg. Score</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">#{evals}</span>
          <span class="stat-lbl">Evaluations</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">#{tasks}</span>
          <span class="stat-lbl">Tasks</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">#{rate}%</span>
          <span class="stat-lbl">Completion</span>
        </div>
      </div>
    </div>
    """
  end

  defp component_projects(projects) do
    items = Enum.map(projects, fn p ->
      """
      <div class="project-card">
        <div class="proj-name">#{safe_html(p.name)}</div>
        <div class="proj-code">Code: #{p.code}</div>
      </div>
      """
    end) |> Enum.join()

    """
    <div class="section-container">
      <h3 class="section-title">Assigned Projects</h3>
      <div class="projects-grid">#{items}</div>
    </div>
    """
  end

  defp component_tasks(tasks, scores) do
    rows = if Enum.empty?(tasks) do
      "<tr><td colspan='4' class='empty-msg'>No tasks assigned during this period.</td></tr>"
    else
      Enum.map(tasks, fn t ->
        score_info = Map.get(scores, t.id)
        score = if score_info, do: score_info.score, else: nil
        score_display = if score, do: "#{score}", else: "—"
        status_cls = "status-#{t.status}"

        """
        <tr>
          <td class="col-task">#{safe_html(t.title)}</td>
          <td class="col-status"><span class="badge #{status_cls}">#{format_status(t.status)}</span></td>
          <td class="col-score">#{score_display}</td>
          <td class="col-rating">#{if score, do: score_to_label(score), else: "—"}</td>
        </tr>
        """
      end) |> Enum.join()
    end

    """
    <div class="section-container">
      <h3 class="section-title">Task Performance</h3>
      <table class="data-table">
        <thead>
          <tr>
            <th class="th-task">Task Description</th>
            <th class="th-status">Status</th>
            <th class="th-score">Score</th>
            <th class="th-rating">Rating</th>
          </tr>
        </thead>
        <tbody>#{rows}</tbody>
      </table>
    </div>
    """
  end

  defp component_evaluations(evaluations) do
    items = if Enum.empty?(evaluations) do
      "<p class='empty-msg'>No evaluations recorded.</p>"
    else
      Enum.map(evaluations, fn e ->
        evaluator = if e.evaluator, do: e.evaluator.username || "Supervisor", else: "System"
        comment = if e.comments && e.comments != "", do: "<div class='eval-comment'>\"#{safe_html(e.comments)}\"</div>", else: ""

        """
        <div class="eval-item">
          <div class="eval-meta">
            <span class="eval-author">#{evaluator}</span>
            <span class="eval-date">#{format_datetime(e.inserted_at)}</span>
          </div>
          <div class="eval-content">
            <div class="score-circle level-#{score_to_level(e.score)}">#{e.score}</div>
            <div class="eval-text">
              <span class="eval-label">#{score_to_label(e.score)}</span>
              #{comment}
            </div>
          </div>
        </div>
        """
      end) |> Enum.join()
    end

    """
    <div class="section-container page-break-avoid">
      <h3 class="section-title">Evaluation History</h3>
      <div class="eval-list">#{items}</div>
    </div>
    """
  end

  defp component_comments(comments) do
    content = if comments && comments != "", do: format_comments(comments), else: "No additional comments."

    """
    <div class="section-container page-break-avoid">
      <h3 class="section-title">Supervisor Remarks</h3>
      <div class="remarks-box">#{content}</div>
    </div>
    """
  end

  defp footer_html do
    """
    <div style="text-align:center; font-size:9px; color:#94a3b8; border-top:1px solid #e2e8f0; padding-top:10px;">
      Generated by Attachment Management System • Confidential • Page <span class="pageNumber"></span>
    </div>
    """
  end

  # --- CSS STYLES ---
  defp pdf_styles do
    """
    /* Base */
    @page { margin: 0; size: A4; }
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #334155; margin: 0; padding: 40px; font-size: 12px; line-height: 1.5; }

    /* Header */
    .header-container { display: table; width: 100%; margin-bottom: 15px; }
    .header-left { display: table-cell; width: 80px; vertical-align: middle; }
    .header-right { display: table-cell; vertical-align: middle; padding-left: 20px; }

    .logo-placeholder {
      width: 60px; height: 60px; background-color: #4c1d95; border-radius: 8px;
      text-align: center; line-height: 60px; color: white; font-weight: bold; font-size: 20px;
    }
    .company-name { margin: 0; color: #1e293b; font-size: 22px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; }
    .report-name { margin: 4px 0 0 0; color: #64748b; font-size: 14px; text-transform: uppercase; letter-spacing: 1.5px; font-weight: 600; }
    .report-period { margin: 2px 0 0 0; font-size: 11px; color: #94a3b8; }
    .header-divider { height: 3px; background: linear-gradient(90deg, #4c1d95, #a78bfa); margin-bottom: 25px; border-radius: 2px; }

    /* Info Box */
    .info-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 15px; margin-bottom: 30px; }
    .info-table { width: 100%; border-collapse: collapse; }
    .info-table td { padding: 4px 0; vertical-align: top; }
    .info-label { color: #64748b; font-size: 10px; text-transform: uppercase; font-weight: 700; width: 15%; }
    .info-value { color: #0f172a; font-size: 13px; width: 35%; }

    /* Sections */
    .section-container { margin-bottom: 30px; }
    .section-title {
      font-size: 15px; color: #4c1d95; border-bottom: 2px solid #e2e8f0;
      padding-bottom: 6px; margin: 0 0 12px 0; font-weight: 700;
    }

    /* Stats */
    .stats-row { display: table; width: 100%; table-layout: fixed; border-spacing: 10px 0; margin-left: -10px; }
    .stat-item {
      display: table-cell; background: white; border: 1px solid #e2e8f0; border-radius: 8px;
      padding: 12px; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .stat-item.highlight { background: #4c1d95; border-color: #4c1d95; }
    .stat-item.highlight .stat-val { color: white; }
    .stat-item.highlight .stat-lbl { color: #e9d5ff; }
    .stat-val { display: block; font-size: 24px; font-weight: 800; line-height: 1; margin-bottom: 4px; }
    .stat-lbl { display: block; font-size: 10px; text-transform: uppercase; font-weight: 600; color: #64748b; }

    /* Projects */
    .projects-grid { overflow: hidden; }
    .project-card {
      display: inline-block; width: 45%; background: #f1f5f9; padding: 8px 12px;
      border-radius: 6px; border-left: 3px solid #7c3aed; margin-right: 10px; margin-bottom: 10px;
    }
    .proj-name { font-weight: 600; color: #334155; font-size: 12px; }
    .proj-code { font-size: 10px; color: #64748b; margin-top: 2px; }

    /* Data Table */
    .data-table { width: 100%; border-collapse: collapse; font-size: 12px; }
    .data-table th {
      text-align: left; padding: 8px; background: #f8fafc; color: #475569;
      text-transform: uppercase; font-size: 10px; font-weight: 700; border-bottom: 2px solid #e2e8f0;
    }
    .data-table td { padding: 8px; border-bottom: 1px solid #f1f5f9; vertical-align: middle; }
    .th-task { width: 50%; } .th-status { width: 20%; } .th-score { width: 15%; } .th-rating { width: 15%; }
    .empty-msg { color: #94a3b8; font-style: italic; padding: 10px 0; text-align: center; }

    /* Badges */
    .badge { padding: 3px 8px; border-radius: 10px; font-size: 9px; font-weight: 700; text-transform: uppercase; display: inline-block; }
    .status-completed { background: #dcfce7; color: #166534; }
    .status-submitted { background: #e0e7ff; color: #3730a3; }
    .status-in_progress { background: #dbeafe; color: #1e40af; }
    .status-pending { background: #f1f5f9; color: #64748b; }

    /* Evaluations */
    .eval-item { margin-bottom: 15px; border-bottom: 1px dashed #e2e8f0; padding-bottom: 12px; }
    .eval-item:last-child { border: none; }
    .eval-meta { font-size: 10px; color: #64748b; margin-bottom: 6px; }
    .eval-author { font-weight: 700; color: #475569; margin-right: 5px; }
    .eval-content { display: table; width: 100%; }
    .score-circle {
      display: table-cell; vertical-align: middle; width: 36px; height: 36px;
      border-radius: 50%; text-align: center; font-weight: 800; font-size: 14px;
      border: 2px solid #e2e8f0; background: #fff;
    }
    .eval-text { display: table-cell; vertical-align: top; padding-left: 12px; }
    .eval-label { font-weight: 700; font-size: 12px; color: #1e293b; display: block; margin-bottom: 2px; }
    .eval-comment { font-style: italic; color: #64748b; font-size: 11px; }

    .level-excellent { border-color: #22c55e; color: #15803d; background: #f0fdf4; }
    .level-good { border-color: #3b82f6; color: #1d4ed8; background: #eff6ff; }
    .level-satisfactory { border-color: #f59e0b; color: #b45309; background: #fffbeb; }
    .level-poor { border-color: #ef4444; color: #b91c1c; background: #fef2f2; }

    /* Remarks */
    .remarks-box { background: #fffbeb; border: 1px solid #fcd34d; border-radius: 6px; padding: 12px; color: #92400e; font-size: 12px; }

    .page-break-avoid { page-break-inside: avoid; }
    """
  end

  # --- HELPERS (Same as before) ---
  defp get_report_title("evaluation_summary"), do: "Evaluation Summary"
  defp get_report_title("monthly_report"), do: "Monthly Progress Report"
  defp get_report_title("final_report"), do: "Final Attachment Report"
  defp get_report_title(_), do: "Attachee Report"

  defp format_status(status), do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  # Re-using your previous helper logic for these:
  defp filter_by_period(tasks, period_start, period_end) do
    Enum.filter(tasks, fn task ->
      task_date = extract_date(task.inserted_at)
      if task_date, do: Date.compare(task_date, period_start) != :lt and Date.compare(task_date, period_end) != :gt, else: true
    end)
  end

  defp filter_evaluations_by_period(evaluations, period_start, period_end) do
    Enum.filter(evaluations, fn eval ->
      eval_date = extract_date(eval.inserted_at)
      if eval_date, do: Date.compare(eval_date, period_start) != :lt and Date.compare(eval_date, period_end) != :gt, else: true
    end)
  end

  defp extract_date(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt)
  defp extract_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp extract_date(%Date{} = d), do: d
  defp extract_date(_), do: nil

  defp safe_html(nil), do: ""
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
  defp format_date(date), do: Calendar.strftime(date, "%d %b, %Y")

  defp format_datetime(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")

  defp format_comments(text) do
    text |> safe_html() |> String.replace("\n", "<br>")
  end
end
