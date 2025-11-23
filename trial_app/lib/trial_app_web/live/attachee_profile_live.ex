defmodule TrialAppWeb.AttacheeProfileLive do
  use TrialAppWeb, :live_view
  alias TrialApp.{Eams, Repo, Reports}
  import TrialAppWeb.Live.Helpers.RoleSwitcher

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    attachee =
      Eams.get_attachee_by_user(user.id) |> Repo.preload([:organization, :department, :user])

    all_tasks = Eams.list_tasks_for_attachee(attachee.id)
    total = length(all_tasks)
    completed = Enum.count(all_tasks, &(&1.status == "completed"))
    overdue = Enum.count(all_tasks, &is_overdue?/1)

    # FIX: Filter reports to only show those that have been SENT by the admin
    reports =
      Reports.list_reports_for_attachee(attachee.id)
      |> Enum.filter(fn r -> r.status == "sent" end)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:attachee, attachee)
     |> assign(:total_tasks, total)
     |> assign(:completed_tasks, completed)
     |> assign(:overdue_tasks, overdue)
     |> assign(:reports, reports)
     |> assign(:selected_report, nil)}
  end

  @impl true
  def handle_info({:switch_role, new_role}, socket), do: handle_role_switch(socket, new_role)

  @impl true
  def handle_event("view_report", %{"id" => report_id}, socket) do
    report = Reports.get_report!(report_id)

    # Mark as viewed safely and update list state immediately
    {updated_report, socket} = mark_and_update_report(socket, report)

    {:noreply, assign(socket, :selected_report, updated_report)}
  end

  @impl true
  def handle_event("download_report", %{"id" => report_id}, socket) do
    report = Reports.get_report!(report_id)
    file_path = Reports.get_report_file_path(report)

    # FIX: Allow download if status is 'generated' OR 'sent' (safety net)
    valid_status? = report.status in ["generated", "sent"]

    if file_path && valid_status? && File.exists?(file_path) do
      # Mark as viewed if not already
      {_updated_report, socket} = mark_and_update_report(socket, report)

      # FIX: Use redirect instead of push_event.
      # This triggers a standard browser download and does NOT require JS hooks.
      {:noreply, redirect(socket, external: "/reports/download/#{report.id}")}
    else
      error_message =
        cond do
          !valid_status? -> "This report is not available for download."
          !file_path -> "Report file path is missing."
          !File.exists?(file_path) -> "Report file not found on server."
          true -> "An unknown error occurred."
        end

      {:noreply, socket |> put_flash(:error, error_message)}
    end
  end

  @impl true
  def handle_event("close_report_view", _params, socket) do
    {:noreply, assign(socket, :selected_report, nil)}
  end

  # -----------------------------------------------------------------
  # Helpers
  # -----------------------------------------------------------------

  # Helper to mark report viewed AND update the lists in assigns
  defp mark_and_update_report(socket, report) do
    if is_nil(report.viewed_at) do
      # 1. Update Database
      {:ok, updated_report} =
        Reports.mark_as_viewed(report, DateTime.utc_now() |> DateTime.truncate(:second))

      # 2. Update the main list so the badge changes instantly from "New" to "Viewed"
      updated_list =
        Enum.map(socket.assigns.reports, fn r ->
          if r.id == updated_report.id, do: updated_report, else: r
        end)

      # 3. Update selected_report if it's currently open
      socket =
        if socket.assigns.selected_report &&
             socket.assigns.selected_report.id == updated_report.id do
          assign(socket, :selected_report, updated_report)
        else
          socket
        end

      # Return updated report and socket with new list
      {updated_report, assign(socket, :reports, updated_list)}
    else
      # No change needed
      {report, socket}
    end
  end

  defp is_overdue?(task) do
    task.due_on && Date.compare(task.due_on, Date.utc_today()) == :lt &&
      task.status not in ["completed", "submitted"]
  end

  defp format_date(date), do: if(date, do: Calendar.strftime(date, "%b %d, %Y"), else: "—")

  defp format_datetime(datetime) do
    if datetime do
      datetime
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%b %d, %Y at %I:%M %p")
    else
      "—"
    end
  end

  defp supervisor_name(attachee) do
    case Eams.list_tasks_for_attachee(attachee.id) |> Repo.preload(project: :supervisor) do
      [] -> "—"
      [%{project: %{supervisor: sup}} | _] -> sup.first_name || sup.username || sup.email
      _ -> "—"
    end
  end

  defp get_initials(name) do
    case name do
      nil ->
        "A"

      name_str ->
        name_str
        |> String.split()
        |> Enum.map(&String.first/1)
        |> Enum.join()
        |> String.slice(0, 2)
        |> String.upcase()
    end
  end

  defp report_type_label(type) do
    case type do
      "evaluation_summary" -> "Evaluation Summary"
      "monthly_report" -> "Monthly Report"
      "final_report" -> "Final Report"
      _ -> String.capitalize(type)
    end
  end

  defp report_status_badge(report) do
    cond do
      is_nil(report.viewed_at) ->
        {"bg-blue-100 text-blue-700", "New"}

      true ->
        {"bg-gray-100 text-gray-700", "Viewed"}
    end
  end

  # -----------------------------------------------------------------
  # Render
  # -----------------------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <main class="flex-1 ml-45 p-8">
          <div class="max-w-4xl mx-auto space-y-8">
            
    <!-- Header -->
            <div class="flex justify-between items-center">
              <div>
                <h1 class="text-3xl font-bold text-gray-800">My Profile</h1>
                <p class="text-gray-600">View and manage your attachee information</p>
              </div>
              <.link
                navigate={~p"/attachee/tasks"}
                class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 text-sm font-medium"
              >
                View Tasks
              </.link>
            </div>
            
    <!-- Profile Card -->
            <div class="bg-white shadow rounded-xl p-6">
              <div class="flex items-start gap-6">
                <div class="shrink-0">
                  <div class="w-24 h-24 rounded-full shadow-lg bg-gradient-to-br from-purple-600 to-indigo-700 flex items-center justify-center">
                    <span class="text-white text-2xl font-bold">
                      {get_initials(@attachee.user.first_name || @attachee.user.username)}
                    </span>
                  </div>
                </div>

                <div class="flex-1">
                  <div class="flex items-center gap-3">
                    <h2 class="text-2xl font-bold text-gray-900">
                      {@attachee.user.first_name || @attachee.user.username || "Attachee"}
                    </h2>
                    <span class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-xs font-medium">
                      Attachee
                    </span>
                  </div>
                  <p class="text-gray-600">{@attachee.user.email}</p>
                </div>
              </div>
            </div>
            
    <!-- Info Grid -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="bg-white shadow rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-800 mb-4">Personal Information</h3>
                <dl class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Phone</dt>
                    <dd class="font-medium">{@attachee.user.phone_number || "—"}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Position</dt>
                    <dd class="font-medium">{@attachee.position}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Attachment Period</dt>
                    <dd class="font-medium">
                      {format_date(@attachee.starts_on)} to {format_date(@attachee.ends_on)}
                    </dd>
                  </div>
                </dl>
              </div>

              <div class="bg-white shadow rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-800 mb-4">Organization</h3>
                <dl class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Company</dt>
                    <dd class="font-medium">{@attachee.organization.name}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Department</dt>
                    <dd class="font-medium">{@attachee.department.name}</dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Supervisor</dt>
                    <dd class="font-medium">{supervisor_name(@attachee)}</dd>
                  </div>
                </dl>
              </div>
            </div>
            
    <!-- Task Summary -->
            <div class="bg-white shadow rounded-xl p-6">
              <h3 class="text-lg font-semibold text-gray-800 mb-4">Task Summary</h3>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6 text-center">
                <div>
                  <p class="text-3xl font-bold text-purple-600">{@total_tasks}</p>
                  <p class="text-sm text-gray-600">Total Tasks</p>
                </div>
                <div>
                  <p class="text-3xl font-bold text-green-600">{@completed_tasks}</p>
                  <p class="text-sm text-gray-600">Completed</p>
                </div>
                <div>
                  <p class={"text-3xl font-bold #{if @overdue_tasks > 0, do: "text-red-600", else: "text-gray-600"}"}>
                    {@overdue_tasks}
                  </p>
                  <p class="text-sm text-gray-600">Overdue</p>
                </div>
              </div>
            </div>
            
    <!-- Reports Section -->
            <div class="bg-white shadow rounded-xl p-6">
              <h3 class="text-lg font-semibold text-gray-800 mb-4">
                My Reports
                <span class="ml-2 text-sm font-normal text-gray-500">
                  ({length(@reports)} reports)
                </span>
              </h3>

              <%= if Enum.empty?(@reports) do %>
                <div class="text-center py-12">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  <p class="mt-4 text-gray-500">No reports available yet</p>
                  <p class="text-sm text-gray-400">
                    Your supervisor will send evaluation reports here
                  </p>
                </div>
              <% else %>
                <div class="space-y-3">
                  <%= for report <- @reports do %>
                    <% {badge_class, badge_text} = report_status_badge(report) %>
                    <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition-colors">
                      <div class="flex items-center justify-between">
                        <div class="flex-1">
                          <div class="flex items-center gap-3">
                            <h4 class="font-medium text-gray-900">
                              {report_type_label(report.report_type)}
                            </h4>
                            <span class={"px-2 py-1 rounded-full text-xs font-medium #{badge_class}"}>
                              {badge_text}
                            </span>
                          </div>
                          <div class="mt-1 text-sm text-gray-600">
                            <span>
                              Period: {format_date(report.period_start)} - {format_date(
                                report.period_end
                              )}
                            </span>
                            <span class="mx-2">•</span>
                            <span>Sent: {format_datetime(report.sent_at || report.inserted_at)}</span>
                          </div>
                          <%= if report.viewed_at do %>
                            <p class="mt-1 text-xs text-gray-500">
                              Viewed on {format_datetime(report.viewed_at)}
                            </p>
                          <% end %>
                        </div>

                        <div class="flex gap-2">
                          <button
                            phx-click="view_report"
                            phx-value-id={report.id}
                            class="px-4 py-2 text-sm bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium"
                          >
                            View Details
                          </button>
                          <button
                            phx-click="download_report"
                            phx-value-id={report.id}
                            class="px-4 py-2 text-sm border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 font-medium"
                          >
                            Download PDF
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>
      
    <!-- Report Details Modal -->
      <%= if @selected_report do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div class="relative top-20 mx-auto p-6 border w-full max-w-2xl shadow-lg rounded-lg bg-white">
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <h3 class="text-xl font-semibold text-gray-900">
                  {report_type_label(@selected_report.report_type)}
                </h3>
                <button
                  phx-click="close_report_view"
                  class="text-gray-400 hover:text-gray-500"
                >
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>

              <div class="border-t border-gray-200 pt-4">
                <dl class="space-y-3">
                  <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Report Period</dt>
                    <dd class="text-sm text-gray-900">
                      {format_date(@selected_report.period_start)} - {format_date(
                        @selected_report.period_end
                      )}
                    </dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-sm font-medium text-gray-500">Generated On</dt>
                    <dd class="text-sm text-gray-900">
                      {format_datetime(@selected_report.inserted_at)}
                    </dd>
                  </div>
                  <%= if @selected_report.sent_at do %>
                    <div class="flex justify-between">
                      <dt class="text-sm font-medium text-gray-500">Sent On</dt>
                      <dd class="text-sm text-gray-900">
                        {format_datetime(@selected_report.sent_at)}
                      </dd>
                    </div>
                  <% end %>
                  <%= if @selected_report.viewed_at do %>
                    <div class="flex justify-between">
                      <dt class="text-sm font-medium text-gray-500">First Viewed</dt>
                      <dd class="text-sm text-gray-900">
                        {format_datetime(@selected_report.viewed_at)}
                      </dd>
                    </div>
                  <% end %>
                </dl>
              </div>

              <div class="border-t border-gray-200 pt-4">
                <p class="text-sm text-gray-600 mb-4">
                  This report contains your performance evaluation for the specified period.
                  Download the PDF to view the complete details including task scores, evaluations, and supervisor feedback.
                </p>
              </div>

              <div class="flex gap-3 pt-4">
                <!-- FIX: This button now triggers the handle_event that performs a redirect -->
                <button
                  phx-click="download_report"
                  phx-value-id={@selected_report.id}
                  class="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium"
                >
                  Download PDF
                </button>
                <button
                  phx-click="close_report_view"
                  class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 font-medium"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
