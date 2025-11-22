defmodule TrialAppWeb.SupervisorLive.ReportModal do
  use TrialAppWeb, :live_component
  alias TrialApp.Reports
  alias TrialApp.Reports.PdfGenerator
  require Logger

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:report_type, "evaluation_summary")
     |> assign(:period_start, get_default_start_date())
     |> assign(:period_end, Date.utc_today())
     |> assign(:include_tasks, true)
     |> assign(:include_evaluations, true)
     |> assign(:include_projects, true)
     |> assign(:include_stats, true)
     |> assign(:custom_comments, "")
     |> assign(:send_to_download, true)
     |> assign(:send_to_profile, false)
     |> assign(:send_to_email, false)
     |> assign(:generating, false)
     |> assign(:error, nil)}
  end

  # ==========================================================================
  # EVENT HANDLERS
  # ==========================================================================

  @impl true
  def handle_event("update_field", %{"report_type" => value}, socket) do
    today = Date.utc_today()

    {start_date, end_date} =
      case value do
        "monthly_report" ->
          {Date.beginning_of_month(today), Date.end_of_month(today)}

        "final_report" ->
          user_start = socket.assigns.attachee.user.inserted_at

          start =
            case user_start do
              %NaiveDateTime{} -> NaiveDateTime.to_date(user_start)
              %DateTime{} -> DateTime.to_date(user_start)
              _ -> Date.add(today, -90)
            end

          {start, today}

        _ ->
          {get_default_start_date(), today}
      end

    {:noreply,
     socket
     |> assign(:report_type, value)
     |> assign(:period_start, start_date)
     |> assign(:period_end, end_date)}
  end

  def handle_event("update_field", %{"period_start" => value}, socket) do
    new_date = parse_date(value, socket.assigns.period_start)
    {:noreply, assign(socket, :period_start, new_date)}
  end

  def handle_event("update_field", %{"period_end" => value}, socket) do
    new_date = parse_date(value, socket.assigns.period_end)
    {:noreply, assign(socket, :period_end, new_date)}
  end

  def handle_event("update_field", %{"custom_comments" => value}, socket) do
    {:noreply, assign(socket, :custom_comments, value)}
  end

  def handle_event("update_field", params, socket) do
    Logger.warning("Unhandled input pattern in ReportModal: #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    field = String.to_atom(section)
    {:noreply, assign(socket, field, !Map.get(socket.assigns, field))}
  end

  # New handler for toggling send options
  @impl true
  def handle_event("toggle_send_option", %{"option" => option}, socket) do
    field = String.to_atom(option)
    {:noreply, assign(socket, field, !Map.get(socket.assigns, field))}
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end

  # ==========================================================================
  # GENERATION LOGIC - UPDATED
  # ==========================================================================

  def handle_event("generate_report", _params, socket) do
    # Validate at least one option is selected
    if !socket.assigns.send_to_download && !socket.assigns.send_to_profile &&
         !socket.assigns.send_to_email do
      {:noreply,
       socket |> assign(:error, "Please select at least one action (Download, Profile, or Email)")}
    else
      socket = socket |> assign(:generating, true) |> assign(:error, nil)

      # DEBUG: Log what we have in socket assigns BEFORE fetching
      Logger.info("=== REPORT GENERATION DEBUG ===")
      Logger.info("Tasks in socket.assigns: #{length(socket.assigns.attachee_tasks)}")
      Logger.info("Evaluations in socket.assigns: #{length(socket.assigns.general_evaluations)}")
      Logger.info("Projects in socket.assigns: #{length(socket.assigns.attachee_projects)}")
      Logger.info("Task scores in socket.assigns: #{map_size(socket.assigns.task_scores)}")

      # FETCH FRESH DATA
      report_data = Reports.gather_report_data(socket.assigns.attachee.id)

      # DEBUG: Log what we fetched
      Logger.info("Tasks fetched: #{length(report_data.tasks)}")
      Logger.info("Evaluations fetched: #{length(report_data.evaluations)}")
      Logger.info("Projects fetched: #{length(report_data.projects)}")
      Logger.info("Task scores fetched: #{map_size(report_data.task_scores)}")
      Logger.info("Stats fetched: #{inspect(report_data.stats)}")
      Logger.info("=== END DEBUG ===")

      # Build the complete generator_assigns map with FETCHED data
      generator_assigns = %{
        attachee: socket.assigns.attachee,
        attachee_stats: report_data.stats,
        attachee_tasks: report_data.tasks,
        task_scores: report_data.task_scores,
        general_evaluations: report_data.evaluations,
        attachee_projects: report_data.projects
      }

      report_options = %{
        attachee_id: socket.assigns.attachee.id,
        generated_by_id: socket.assigns.current_user.id,
        report_type: socket.assigns.report_type,
        period_start: socket.assigns.period_start,
        period_end: socket.assigns.period_end,
        include_tasks: socket.assigns.include_tasks,
        include_evaluations: socket.assigns.include_evaluations,
        include_projects: socket.assigns.include_projects,
        include_stats: socket.assigns.include_stats,
        custom_comments: socket.assigns.custom_comments
      }

      case process_report_generation(report_options, generator_assigns) do
        {:ok, report} ->
          handle_multiple_actions(socket, report)

        {:error, reason} ->
          Logger.error("Report generation failed: #{inspect(reason)}")

          {:noreply,
           socket
           |> assign(:generating, false)
           |> assign(:error, "Error: #{inspect(reason)}")}
      end
    end
  end

  defp process_report_generation(options, assigns) do
    report_attrs =
      Map.take(options, [
        :attachee_id,
        :generated_by_id,
        :report_type,
        :period_start,
        :period_end
      ])

    Reports.ensure_reports_directory()
    filename = Reports.generate_filename(assigns.attachee, options.report_type)
    file_path = Reports.reports_directory() |> Path.join(filename)

    with {:ok, report} <- Reports.create_report(report_attrs),
         {:ok, _path} <- PdfGenerator.generate_pdf(report, assigns, options, file_path),
         {:ok, updated_report} <-
           Reports.update_report(report, %{
             file_path: file_path,
             file_name: filename,
             status: "generated"
           }) do
      {:ok, updated_report}
    else
      {:error, reason} = error ->
        Logger.error("Process report generation failed at some step: #{inspect(reason)}")
        error
    end
  end

  # ==========================================================================
  # HELPERS - UPDATED
  # ==========================================================================

  defp parse_date(value, fallback) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> fallback
    end
  end

  # New function to handle multiple actions
  defp handle_multiple_actions(socket, report) do
    socket = assign(socket, :generating, false)

    # Handle send to profile
    socket =
      if socket.assigns.send_to_profile do
        case Reports.update_report(report, %{status: "sent", sent_at: DateTime.utc_now()}) do
          {:ok, _} ->
            send(self(), {:put_flash, :info, "Report sent to attachee profile successfully."})
            socket

          {:error, _} ->
            send(self(), {:put_flash, :error, "Failed to send report to profile."})
            socket
        end
      else
        socket
      end

    # Handle email
    socket =
      if socket.assigns.send_to_email do
        case Reports.update_report(report, %{status: "sent", sent_at: DateTime.utc_now()}) do
          {:ok, _} ->
            # TODO: Implement actual email sending logic here
            send(
              self(),
              {:put_flash, :info, "Report emailed to #{socket.assigns.attachee.user.email}."}
            )

            socket

          {:error, _} ->
            send(self(), {:put_flash, :error, "Failed to email report."})
            socket
        end
      else
        socket
      end

    # Handle download (this should be last and trigger redirect if selected)
    if socket.assigns.send_to_download do
      send(self(), :close_modal)

      {:noreply,
       socket
       |> push_event("close_modal", %{})
       |> redirect(external: "/reports/download/#{report.id}")}
    else
      send(self(), :close_modal)
      {:noreply, socket}
    end
  end

  defp get_default_start_date do
    Date.utc_today() |> Date.add(-30)
  end

  # Helper function to get button text
  defp get_button_text(send_to_download, send_to_profile, send_to_email) do
    selected = []
    selected = if send_to_download, do: ["Download" | selected], else: selected
    selected = if send_to_profile, do: ["Send to Profile" | selected], else: selected
    selected = if send_to_email, do: ["Email" | selected], else: selected

    case selected do
      [] -> "Select Action"
      [single] -> single
      multiple -> Enum.join(multiple, " & ")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-gray-900 bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 flex items-center justify-between shrink-0">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center backdrop-blur-sm">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
            </div>
            <div>
              <h2 class="text-xl font-bold text-white">Generate Report</h2>
              <p class="text-sm text-blue-100">
                For {@attachee.user.username || @attachee.user.email}
              </p>
            </div>
          </div>
          <button
            phx-click="close"
            phx-target={@myself}
            class="text-white hover:bg-white/20 rounded-full p-2 transition"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <div class="p-6 overflow-y-auto flex-1">
          <%= if @error do %>
            <div class="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg flex items-center gap-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              {@error}
            </div>
          <% end %>

          <form id="report-form" phx-submit="generate_report" phx-target={@myself} class="space-y-6">
            <div class="bg-gray-50 p-4 rounded-xl border border-gray-200">
              <label class="block text-sm font-bold text-gray-700 mb-2">1. Select Report Type</label>
              <select
                name="report_type"
                phx-change="update_field"
                phx-target={@myself}
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              >
                <option value="evaluation_summary" selected={@report_type == "evaluation_summary"}>
                  Evaluation Summary (Scores & Stats)
                </option>
                <option value="monthly_report" selected={@report_type == "monthly_report"}>
                  Monthly Progress Report
                </option>
                <option value="final_report" selected={@report_type == "final_report"}>
                  End of Attachment Final Report
                </option>
              </select>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Period Start</label>
                <input
                  type="date"
                  name="period_start"
                  value={@period_start}
                  phx-change="update_field"
                  phx-target={@myself}
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                />
              </div>
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Period End</label>
                <input
                  type="date"
                  name="period_end"
                  value={@period_end}
                  phx-change="update_field"
                  phx-target={@myself}
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                />
              </div>
            </div>

            <hr class="border-gray-200" />

            <div>
              <label class="block text-sm font-bold text-gray-700 mb-3">2. Report Content</label>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <label class={[
                  "flex items-center gap-3 cursor-pointer group p-3 border rounded-lg hover:bg-purple-50 transition",
                  if(@include_stats, do: "border-purple-300 bg-purple-50", else: "border-gray-200")
                ]}>
                  <input
                    type="checkbox"
                    checked={@include_stats}
                    phx-click="toggle_section"
                    phx-target={@myself}
                    phx-value-section="include_stats"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <span class="text-sm font-medium text-gray-700">Performance Stats</span>
                </label>

                <label class={[
                  "flex items-center gap-3 cursor-pointer group p-3 border rounded-lg hover:bg-purple-50 transition",
                  if(@include_evaluations,
                    do: "border-purple-300 bg-purple-50",
                    else: "border-gray-200"
                  )
                ]}>
                  <input
                    type="checkbox"
                    checked={@include_evaluations}
                    phx-click="toggle_section"
                    phx-target={@myself}
                    phx-value-section="include_evaluations"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <span class="text-sm font-medium text-gray-700">Evaluation History</span>
                </label>

                <label class={[
                  "flex items-center gap-3 cursor-pointer group p-3 border rounded-lg hover:bg-purple-50 transition",
                  if(@include_tasks, do: "border-purple-300 bg-purple-50", else: "border-gray-200")
                ]}>
                  <input
                    type="checkbox"
                    checked={@include_tasks}
                    phx-click="toggle_section"
                    phx-target={@myself}
                    phx-value-section="include_tasks"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <span class="text-sm font-medium text-gray-700">Tasks List</span>
                </label>

                <label class={[
                  "flex items-center gap-3 cursor-pointer group p-3 border rounded-lg hover:bg-purple-50 transition",
                  if(@include_projects, do: "border-purple-300 bg-purple-50", else: "border-gray-200")
                ]}>
                  <input
                    type="checkbox"
                    checked={@include_projects}
                    phx-click="toggle_section"
                    phx-target={@myself}
                    phx-value-section="include_projects"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <span class="text-sm font-medium text-gray-700">Project Details</span>
                </label>
              </div>
            </div>

            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                Additional Comments
              </label>
              <textarea
                name="custom_comments"
                phx-change="update_field"
                phx-target={@myself}
                rows="3"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none"
                placeholder="Enter any specific notes for this report..."
              ><%= @custom_comments %></textarea>
            </div>

            <div>
              <label class="block text-sm font-bold text-gray-700 mb-3">
                3. Actions (Select one or more)
              </label>
              <div class="space-y-2">
                <label class={[
                  "flex items-center gap-3 cursor-pointer p-3 border rounded-lg hover:bg-gray-50 transition",
                  if(@send_to_download,
                    do: "ring-2 ring-purple-500 border-transparent bg-purple-50",
                    else: "border-gray-200"
                  )
                ]}>
                  <input
                    type="checkbox"
                    checked={@send_to_download}
                    phx-click="toggle_send_option"
                    phx-target={@myself}
                    phx-value-option="send_to_download"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <div class="flex-1">
                    <div class="text-sm font-bold text-gray-900">Download PDF</div>
                    <div class="text-xs text-gray-500">Save directly to your device</div>
                  </div>
                  <svg
                    class="w-5 h-5 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                    />
                  </svg>
                </label>

                <label class={[
                  "flex items-center gap-3 cursor-pointer p-3 border rounded-lg hover:bg-gray-50 transition",
                  if(@send_to_profile,
                    do: "ring-2 ring-purple-500 border-transparent bg-purple-50",
                    else: "border-gray-200"
                  )
                ]}>
                  <input
                    type="checkbox"
                    checked={@send_to_profile}
                    phx-click="toggle_send_option"
                    phx-target={@myself}
                    phx-value-option="send_to_profile"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <div class="flex-1">
                    <div class="text-sm font-bold text-gray-900">Send to Profile</div>
                    <div class="text-xs text-gray-500">Attachee can view it in their dashboard</div>
                  </div>
                  <svg
                    class="w-5 h-5 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                    />
                  </svg>
                </label>

                <label class={[
                  "flex items-center gap-3 cursor-pointer p-3 border rounded-lg hover:bg-gray-50 transition",
                  if(@send_to_email,
                    do: "ring-2 ring-purple-500 border-transparent bg-purple-50",
                    else: "border-gray-200"
                  )
                ]}>
                  <input
                    type="checkbox"
                    checked={@send_to_email}
                    phx-click="toggle_send_option"
                    phx-target={@myself}
                    phx-value-option="send_to_email"
                    class="w-5 h-5 text-purple-600 rounded focus:ring-purple-500"
                  />
                  <div class="flex-1">
                    <div class="text-sm font-bold text-gray-900">Email Report</div>
                    <div class="text-xs text-gray-500">Send to {@attachee.user.email}</div>
                  </div>
                  <svg
                    class="w-5 h-5 text-gray-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                </label>
              </div>
            </div>
          </form>
        </div>

        <div class="bg-gray-50 px-6 py-4 flex items-center justify-end gap-3 border-t border-gray-200 shrink-0">
          <button
            phx-click="close"
            phx-target={@myself}
            type="button"
            class="px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-100 transition"
            disabled={@generating}
          >
            Cancel
          </button>
          <button
            phx-click="generate_report"
            phx-target={@myself}
            type="button"
            class="px-6 py-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg text-sm font-medium hover:from-blue-700 hover:to-purple-700 transition shadow-lg disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            disabled={@generating}
          >
            <%= if @generating do %>
              <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                >
                </circle>
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                >
                </path>
              </svg>
              Processing...
            <% else %>
              {get_button_text(@send_to_download, @send_to_profile, @send_to_email)}
            <% end %>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
