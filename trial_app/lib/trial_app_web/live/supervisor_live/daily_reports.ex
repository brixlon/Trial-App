defmodule TrialAppWeb.SupervisorLive.DailyReports do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    
    # Get departments where user is supervisor
    departments = Orgs.list_departments_for_supervisor(current_user.id)
    
    # Get all reports from teams in supervised departments
    reports = if Enum.any?(departments) do
      department_ids = Enum.map(departments, & &1.id)
      Orgs.list_daily_reports(%{preloads: [:team_lead, :team, :department]})
      |> Enum.filter(fn r -> r.supervisor_id == current_user.id end)
      |> Enum.sort_by(& &1.report_date, {:desc, Date})
    else
      []
    end

    {:ok,
     socket
     |> assign(:departments, departments)
     |> assign(:reports, reports)
     |> assign(:selected_report, nil)
     |> assign(:show_report_modal, false)}
  end

  @impl true
  def handle_event("view_report", %{"id" => id}, socket) do
    report = Orgs.get_daily_report!(id, %{preloads: [:team_lead, :team, :department]})
    
    {:noreply,
     socket
     |> assign(:selected_report, report)
     |> assign(:show_report_modal, true)}
  end

  def handle_event("close_report_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_report_modal, false)
     |> assign(:selected_report, nil)}
  end

  def handle_event("mark_reviewed", %{"id" => id}, socket) do
    report = Orgs.get_daily_report!(id)
    
    case Orgs.update_daily_report(report, %{status: "reviewed"}) do
      {:ok, _report} ->
        current_user = socket.assigns.current_scope.user
        reports = Orgs.list_daily_reports(%{preloads: [:team_lead, :team, :department]})
          |> Enum.filter(fn r -> r.supervisor_id == current_user.id end)
          |> Enum.sort_by(& &1.report_date, {:desc, Date})

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> assign(:show_report_modal, false)
         |> assign(:selected_report, nil)
         |> put_flash(:info, "Report marked as reviewed!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update report")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <h1 class="text-3xl font-bold text-gray-900">Daily Reports from Team Leads</h1>
        <p class="text-gray-600 mt-2">
          Reports from teams in your supervised departments
        </p>
      </div>

      <%= if Enum.empty?(@departments) do %>
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 text-center">
          <p class="text-yellow-800">
            You are not assigned as a supervisor for any departments.
          </p>
        </div>
      <% else %>
        <!-- Reports List -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Team Lead</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Team</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Department</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for report <- @reports do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= Calendar.strftime(report.report_date, "%B %d, %Y") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= "#{report.team_lead.first_name || ""} #{report.team_lead.last_name || ""}" |> String.trim() %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= report.team.name %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= report.department.name %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"px-2 py-1 text-xs font-semibold rounded-full #{status_class(report.status)}"}>
                      <%= String.capitalize(report.status) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                    <button
                      phx-click="view_report"
                      phx-value-id={report.id}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      View
                    </button>
                    <%= if report.status == "submitted" do %>
                      <button
                        phx-click="mark_reviewed"
                        phx-value-id={report.id}
                        class="text-green-600 hover:text-green-900"
                      >
                        Mark Reviewed
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
              <%= if Enum.empty?(@reports) do %>
                <tr>
                  <td colspan="6" class="px-6 py-8 text-center text-gray-500">
                    No reports received yet.
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>

      <!-- Report Detail Modal -->
      <%= if @show_report_modal && @selected_report do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-2xl w-full max-w-3xl max-h-[90vh] overflow-y-auto">
            <div class="p-6 border-b border-gray-200 flex justify-between items-center">
              <h2 class="text-2xl font-bold text-gray-900">
                Daily Report - <%= Calendar.strftime(@selected_report.report_date, "%B %d, %Y") %>
              </h2>
              <button
                phx-click="close_report_modal"
                class="text-gray-400 hover:text-gray-600"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="p-6 space-y-6">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-semibold text-gray-700">Team Lead</label>
                  <p class="mt-1 text-gray-900">
                    <%= "#{@selected_report.team_lead.first_name || ""} #{@selected_report.team_lead.last_name || ""}" |> String.trim() %>
                  </p>
                </div>
                <div>
                  <label class="block text-sm font-semibold text-gray-700">Team</label>
                  <p class="mt-1 text-gray-900"><%= @selected_report.team.name %></p>
                </div>
                <div>
                  <label class="block text-sm font-semibold text-gray-700">Department</label>
                  <p class="mt-1 text-gray-900"><%= @selected_report.department.name %></p>
                </div>
                <div>
                  <label class="block text-sm font-semibold text-gray-700">Status</label>
                  <span class={"mt-1 inline-block px-3 py-1 text-sm font-semibold rounded-full #{status_class(@selected_report.status)}"}>
                    <%= String.capitalize(@selected_report.status) %>
                  </span>
                </div>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Summary</label>
                <p class="text-gray-900 bg-gray-50 p-4 rounded-lg">
                  <%= @selected_report.summary || "No summary provided" %>
                </p>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Tasks Completed</label>
                <p class="text-gray-900 bg-gray-50 p-4 rounded-lg whitespace-pre-wrap">
                  <%= @selected_report.tasks_completed || "No tasks listed" %>
                </p>
              </div>

              <%= if @selected_report.challenges && @selected_report.challenges != "" do %>
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">Challenges</label>
                  <p class="text-gray-900 bg-yellow-50 p-4 rounded-lg whitespace-pre-wrap">
                    <%= @selected_report.challenges %>
                  </p>
                </div>
              <% end %>

              <%= if @selected_report.next_day_plans && @selected_report.next_day_plans != "" do %>
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">Next Day Plans</label>
                  <p class="text-gray-900 bg-blue-50 p-4 rounded-lg whitespace-pre-wrap">
                    <%= @selected_report.next_day_plans %>
                  </p>
                </div>
              <% end %>

              <div class="flex justify-end gap-3 pt-4 border-t">
                <button
                  phx-click="close_report_modal"
                  class="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                >
                  Close
                </button>
                <%= if @selected_report.status == "submitted" do %>
                  <button
                    phx-click="mark_reviewed"
                    phx-value-id={@selected_report.id}
                    class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                  >
                    Mark as Reviewed
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_class("draft"), do: "bg-gray-100 text-gray-800"
  defp status_class("submitted"), do: "bg-blue-100 text-blue-800"
  defp status_class("reviewed"), do: "bg-green-100 text-green-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"
end

