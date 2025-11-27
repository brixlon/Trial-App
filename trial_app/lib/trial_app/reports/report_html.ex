defmodule TrialApp.Reports.ReportHTML do
  use Phoenix.Component
  import Phoenix.HTML
  # Import if needed, or define local components
  import TrialAppWeb.CoreComponents, only: []

  def report(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <title>{@title}</title>
        <style>
          <%= raw(@css) %>
        </style>
      </head>
      <body>
        <.header_component
          organization={@organization}
          title={@title}
          period_start={@period_start}
          period_end={@period_end}
        />
        <.info_grid attachee={@attachee} department={@department} attachee_name={@attachee_name} />

        <div class="content-body">
          <%= if @include_stats do %>
            <.stats_component
              avg_score={@avg_score}
              eval_count={@eval_count}
              total_tasks={@total_tasks}
              comp_rate={@comp_rate}
            />
          <% end %>

          <%= if @include_projects && length(@projects) > 0 do %>
            <.projects_component projects={@projects} />
          <% end %>

          <%= if @include_tasks do %>
            <.tasks_component monthly_tasks={@monthly_tasks} attachee={@attachee} />
          <% end %>

          <%= if @include_evaluations do %>
            <.evaluations_component
              evaluations={@filtered_evals}
              month_1_score={@month_1_score}
              month_2_score={@month_2_score}
              month_3_score={@month_3_score}
              total_score={@total_score}
              comments={@comments}
            />
          <% end %>

          <.comments_component comments={@custom_comments} />
        </div>
      </body>
    </html>
    """
  end

  def header_component(assigns) do
    ~H"""
    <div class="header-container">
      <div class="header-left">
        <%= if url = logo_data_url() do %>
          <img src={url} class="logo-img" alt="Value8" />
        <% else %>
          <div class="logo-placeholder">
            {if @organization,
              do: String.slice(@organization.name, 0, 2) |> String.upcase(),
              else: "CO"}
          </div>
        <% end %>
      </div>
      <div class="header-right">
        <h1 class="company-name">{if @organization, do: @organization.name, else: "Company Name"}</h1>
        <div class="report-meta">
          <h2 class="report-name">{@title}</h2>
          <p class="report-period">
            Period: {format_date(@period_start)} – {format_date(@period_end)}
          </p>
        </div>
      </div>
    </div>
    <div class="header-divider"></div>
    """
  end

  def info_grid(assigns) do
    ~H"""
    <div class="info-box">
      <table class="info-table">
        <tr>
          <td class="info-label">Attachee Name</td>
          <td class="info-value"><strong>{@attachee_name}</strong></td>
          <td class="info-label">Department</td>
          <td class="info-value">{if @department, do: @department.name, else: "—"}</td>
        </tr>
        <tr>
          <td class="info-label">Email</td>
          <td class="info-value">{@attachee.user.email}</td>
          <td class="info-label">Position</td>
          <td class="info-value">{@attachee.position || "Industrial Attachee"}</td>
        </tr>
        <tr>
          <td class="info-label">Attachment Duration</td>
          <td class="info-value" colspan="3">
            {format_date(@attachee.starts_on)} — {format_date(@attachee.ends_on)}
          </td>
        </tr>
      </table>
    </div>
    """
  end

  def stats_component(assigns) do
    ~H"""
    <div class="section-container">
      <h3 class="section-title">Performance Overview</h3>
      <div class="stats-row">
        <div class="stat-item highlight">
          <span class="stat-val">{@avg_score}</span>
          <span class="stat-lbl">Avg. Score</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">{@eval_count}</span>
          <span class="stat-lbl">Evaluations</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">{@total_tasks}</span>
          <span class="stat-lbl">Tasks</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">{@comp_rate}%</span>
          <span class="stat-lbl">Completion</span>
        </div>
      </div>
    </div>
    """
  end

  def projects_component(assigns) do
    ~H"""
    <div class="section-container">
      <h3 class="section-title">Assigned Projects</h3>
      <div class="projects-grid">
        <%= for project <- @projects do %>
          <div class="project-card">
            <div class="proj-name">{project.name}</div>
            <div class="proj-code">Code: {project.code}</div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def tasks_component(assigns) do
    ~H"""
    <div class="section-container">
      <h3 class="section-title">Monthly Task Performance</h3>

      <%= for month_num <- [1, 2, 3] do %>
        <% tasks = Map.get(assigns.monthly_tasks, month_num, []) %>
        <% month_name = get_month_name(assigns.attachee.starts_on, month_num) %>
        <div class="mb-6 page-break-avoid">
          <h4 class="text-sm font-bold text-gray-700 mb-3 uppercase border-b pb-1">
            Month {month_num} ({month_name}) Performance
          </h4>

          <table class="data-table">
            <thead>
              <tr>
                <th class="th-task">Task & Supervisor Comment</th>
                <th class="th-status">Status</th>
                <th class="th-rating">Rating</th>
              </tr>
            </thead>
            <tbody>
              <%= if Enum.empty?(tasks) do %>
                <tr>
                  <td colspan="3" class="empty-msg">No tasks completed in {month_name}.</td>
                </tr>
              <% else %>
                <%= for task <- tasks do %>
                  <tr>
                    <td class="col-task">
                      <div class="font-bold">{task.title}</div>
                      <%= if task.rating_comment do %>
                        <div class="text-xs text-gray-500 mt-1 italic">
                          " {task.rating_comment} "
                        </div>
                      <% end %>
                    </td>
                    <td class="col-status">
                      <span class={"badge status-#{task.status}"}>{format_status(task.status)}</span>
                    </td>
                    <td class="col-rating">
                      <%= if task.rating do %>
                        <span class={"font-bold " <> rating_class(task.rating)}>
                          {TrialApp.Eams.Task.rating_label(task.rating)}
                        </span>
                      <% else %>
                        <span class="text-gray-400">—</span>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  def evaluations_component(assigns) do
    ~H"""
    <div class="section-container page-break-avoid">
      <h3 class="section-title">3-Month Performance Summary</h3>

      <div class="stats-row mb-6">
        <div class="stat-item">
          <span class="stat-val">{@month_1_score || 0}</span>
          <span class="stat-lbl">Month 1 Score</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">{@month_2_score || 0}</span>
          <span class="stat-lbl">Month 2 Score</span>
        </div>
        <div class="stat-item">
          <span class="stat-val">{@month_3_score || 0}</span>
          <span class="stat-lbl">Month 3 Score</span>
        </div>
        <div class="stat-item highlight">
          <span class="stat-val">{@total_score || 0}</span>
          <span class="stat-lbl">Total Score</span>
        </div>
      </div>

      <div class="remarks-box">
        <h4 class="font-bold text-sm mb-2 text-yellow-900">Final Remarks</h4>
        <%= if @comments && @comments != "" do %>
          {raw(String.replace(@comments, "\n", "<br>"))}
        <% else %>
          No final remarks recorded.
        <% end %>
      </div>
    </div>
    """
  end

  def comments_component(assigns) do
    ~H"""
    <!-- Deprecated: Comments are now integrated into evaluations_component -->
    """
  end

  # --- CSS Styles ---
  def pdf_styles do
    """
    /* Base */
    @page { margin: 0; size: A4; }
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #334155; margin: 0; padding: 40px; font-size: 12px; line-height: 1.5; }

    /* Header */
    .header-container { display: table; width: 100%; margin-bottom: 15px; }
    .header-left { display: table-cell; width: 80px; vertical-align: middle; }
    .header-right { display: table-cell; vertical-align: middle; padding-left: 20px; }

    .logo-img { width: 80px; height: auto; display: block; }
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

  # --- Helpers ---
  defp format_date(nil), do: "N/A"
  defp format_date(date), do: Calendar.strftime(date, "%d %b, %Y")

  defp format_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp rating_class(rating) do
    case rating do
      "poor" -> "text-red-600"
      "below_average" -> "text-orange-600"
      "average" -> "text-yellow-600"
      "meets_expectations" -> "text-blue-600"
      "exceeds_expectations" -> "text-green-600"
      _ -> "text-gray-600"
    end
  end

  defp get_month_name(start_date, month_num) when is_integer(month_num) do
    if start_date do
      # Calculate the month based on start date + (month_num - 1) months
      target_date = Date.add(start_date, (month_num - 1) * 30)
      Calendar.strftime(target_date, "%B %Y")
    else
      "Month #{month_num}"
    end
  end

  defp logo_data_url do
    path = Application.app_dir(:trial_app, "priv/static/images/value8-logo.png")

    case File.read(path) do
      {:ok, binary} -> "data:image/png;base64,#{Base.encode64(binary)}"
      _ -> nil
    end
  end
end
