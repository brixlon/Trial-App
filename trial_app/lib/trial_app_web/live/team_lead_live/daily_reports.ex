defmodule TrialAppWeb.TeamLeadLive.DailyReports do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Accounts, Repo}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Get teams where user is team lead
    teams = Orgs.list_teams_for_team_lead(current_user.id)

    # Get existing reports
    reports = if Enum.any?(teams) do
      team_ids = Enum.map(teams, & &1.id)
      Orgs.list_daily_reports(%{preloads: [:team, :department, :supervisor]})
      |> Enum.filter(fn r -> r.team_lead_id == current_user.id end)
    else
      []
    end

    {:ok,
     socket
     |> assign(:teams, teams)
     |> assign(:reports, reports)
     |> assign(:show_form, false)
     |> assign(:form_data, %{
       report_date: Date.utc_today() |> Date.to_string(),
       summary: "",
       tasks_completed: "",
       challenges: "",
       next_day_plans: "",
       team_id: "",
       status: "draft"
     })
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Daily Report")
    |> assign(:show_form, true)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Daily Reports")
    |> assign(:show_form, false)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    report = Orgs.get_daily_report!(id, %{preloads: [:team, :department, :supervisor]})

    socket
    |> assign(:page_title, "Edit Daily Report")
    |> assign(:editing_report, report)
    |> assign(:show_form, true)
    |> assign(:form_data, %{
      report_date: report.report_date |> Date.to_string(),
      summary: report.summary || "",
      tasks_completed: report.tasks_completed || "",
      challenges: report.challenges || "",
      next_day_plans: report.next_day_plans || "",
      team_id: to_string(report.team_id),
      status: report.status
    })
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    report = Orgs.get_daily_report!(id, %{preloads: [:team, :department, :supervisor, :team_lead]})

    socket
    |> assign(:page_title, "Daily Report")
    |> assign(:report, report)
  end

  @impl true
  def handle_event("new_report", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_report, nil)
     |> assign(:form_data, %{
       report_date: Date.utc_today() |> Date.to_string(),
       summary: "",
       tasks_completed: "",
       challenges: "",
       next_day_plans: "",
       team_id: "",
       status: "draft"
     })
     |> assign(:errors, %{})}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:editing_report, nil)
     |> assign(:form_data, %{
       report_date: Date.utc_today() |> Date.to_string(),
       summary: "",
       tasks_completed: "",
       challenges: "",
       next_day_plans: "",
       team_id: "",
       status: "draft"
     })
     |> assign(:errors, %{})}
  end

  def handle_event("update_form", %{"report" => params}, socket) do
    form_data = Map.merge(socket.assigns.form_data, params)
    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("save_report", %{"report" => params}, socket) do
    current_user = socket.assigns.current_scope.user

    # Get selected team
    team = Orgs.get_team!(String.to_integer(params["team_id"])) |> Repo.preload(:department)

    # Get supervisor from department
    department = Orgs.get_department!(team.department_id) |> Repo.preload(:supervisor)

    if is_nil(department.supervisor_id) do
      {:noreply,
       socket
       |> assign(:errors, %{team_id: "This team's department does not have a supervisor assigned"})
       |> put_flash(:error, "Cannot create report: Department supervisor not assigned")}
    else
      report_params = %{
        report_date: parse_date(params["report_date"]),
        summary: params["summary"],
        tasks_completed: params["tasks_completed"],
        challenges: params["challenges"],
        next_day_plans: params["next_day_plans"],
        team_lead_id: current_user.id,
        team_id: team.id,
        supervisor_id: department.supervisor_id,
        department_id: team.department_id,
        status: params["status"] || "draft"
      }

      result = if socket.assigns[:editing_report] do
        Orgs.update_daily_report(socket.assigns.editing_report, report_params)
      else
        Orgs.create_daily_report(report_params)
      end

      case result do
        {:ok, _report} ->
          # Refresh reports
          reports = Orgs.list_daily_reports(%{preloads: [:team, :department, :supervisor]})
            |> Enum.filter(fn r -> r.team_lead_id == current_user.id end)

          {:noreply,
           socket
           |> assign(:reports, reports)
           |> assign(:show_form, false)
           |> assign(:editing_report, nil)
           |> assign(:form_data, %{
             report_date: Date.utc_today() |> Date.to_string(),
             summary: "",
             tasks_completed: "",
             challenges: "",
             next_day_plans: "",
             team_id: "",
             status: "draft"
           })
           |> assign(:errors, %{})
           |> put_flash(:info, "Daily report saved successfully!")}

        {:error, changeset} ->
          errors = traverse_errors(changeset)
          {:noreply, assign(socket, :errors, errors)}
      end
    end
  end

  def handle_event("submit_report", %{"id" => id}, socket) do
    report = Orgs.get_daily_report!(id)

    case Orgs.submit_daily_report(report) do
      {:ok, _report} ->
        current_user = socket.assigns.current_scope.user
        reports = Orgs.list_daily_reports(%{preloads: [:team, :department, :supervisor]})
          |> Enum.filter(fn r -> r.team_lead_id == current_user.id end)

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> put_flash(:info, "Report submitted to supervisor!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to submit report")}
    end
  end

  def handle_event("delete_report", %{"id" => id}, socket) do
    report = Orgs.get_daily_report!(id)

    case Orgs.delete_daily_report(report) do
      {:ok, _report} ->
        current_user = socket.assigns.current_scope.user
        reports = Orgs.list_daily_reports(%{preloads: [:team, :department, :supervisor]})
          |> Enum.filter(fn r -> r.team_lead_id == current_user.id end)

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> put_flash(:info, "Report deleted successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete report")}
    end
  end

  def handle_event("edit_report", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/team_lead/daily_reports/#{id}/edit")}
  end

  def handle_event("view_report", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/team_lead/daily_reports/#{id}")}
  end

  def handle_event("back_to_reports", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/team_lead/daily_reports")}
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @impl true
  def render(assigns) do
    case assigns.live_action do
      :show -> render_show(assigns)
      _ -> render_index(assigns)
    end
  end

  defp render_index(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold text-gray-900">Daily Reports</h1>
        <%= if Enum.any?(@teams) do %>
          <button
            phx-click="new_report"
            class="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 font-semibold"
          >
            + New Report
          </button>
        <% else %>
          <p class="text-gray-500">You are not assigned as a team lead for any teams.</p>
        <% end %>
      </div>

      <!-- Report Form -->
      <%= if @show_form do %>
        <.daily_report_form
          form_data={@form_data}
          teams={@teams}
          errors={@errors}
          editing={!is_nil(@editing_report)}
        />
      <% end %>

      <!-- Reports List -->
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Team</th>
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
                  <%= report.team.name %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"px-2 py-1 text-xs font-semibold rounded-full #{status_class(report.status)}"}>
                    <%= String.capitalize(report.status) %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                  <%= if report.status == "draft" do %>
                    <button
                      phx-click="submit_report"
                      phx-value-id={report.id}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      Submit
                    </button>
                    <button
                      phx-click="edit_report"
                      phx-value-id={report.id}
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      Edit
                    </button>
                    <button
                      phx-click="delete_report"
                      phx-value-id={report.id}
                      onclick="return confirm('Are you sure?')"
                      class="text-red-600 hover:text-red-900"
                    >
                      Delete
                    </button>
                  <% else %>
                    <button
                      phx-click="view_report"
                      phx-value-id={report.id}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      View
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
            <%= if Enum.empty?(@reports) do %>
              <tr>
                <td colspan="4" class="px-6 py-8 text-center text-gray-500">
                  No reports yet. Create your first daily report!
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_show(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <button
          phx-click={JS.push("back_to_reports")}
          class="text-blue-600 hover:text-blue-800 mb-4"
        >
          ← Back to Reports
        </button>
        <h1 class="text-3xl font-bold text-gray-900">
          Daily Report - <%= Calendar.strftime(@report.report_date, "%B %d, %Y") %>
        </h1>
      </div>

      <div class="bg-white rounded-lg shadow-lg p-6 space-y-6">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700">Team</label>
            <p class="mt-1 text-gray-900"><%= @report.team.name %></p>
          </div>
          <div>
            <label class="block text-sm font-semibold text-gray-700">Status</label>
            <span class={"mt-1 inline-block px-3 py-1 text-sm font-semibold rounded-full #{status_class(@report.status)}"}>
              <%= String.capitalize(@report.status) %>
            </span>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Summary</label>
          <p class="text-gray-900 bg-gray-50 p-4 rounded-lg">
            <%= @report.summary || "No summary provided" %>
          </p>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Tasks Completed</label>
          <p class="text-gray-900 bg-gray-50 p-4 rounded-lg whitespace-pre-wrap">
            <%= @report.tasks_completed || "No tasks listed" %>
          </p>
        </div>

        <%= if @report.challenges && @report.challenges != "" do %>
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-2">Challenges</label>
            <p class="text-gray-900 bg-yellow-50 p-4 rounded-lg whitespace-pre-wrap">
              <%= @report.challenges %>
            </p>
          </div>
        <% end %>

        <%= if @report.next_day_plans && @report.next_day_plans != "" do %>
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-2">Next Day Plans</label>
            <p class="text-gray-900 bg-blue-50 p-4 rounded-lg whitespace-pre-wrap">
              <%= @report.next_day_plans %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp daily_report_form(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
      <h2 class="text-2xl font-bold mb-4">
        <%= if @editing, do: "Edit Daily Report", else: "New Daily Report" %>
      </h2>

      <form phx-submit="save_report" phx-change="update_form" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-2">Report Date *</label>
            <input
              type="date"
              name="report[report_date]"
              value={@form_data.report_date}
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
            />
            <%= if @errors[:report_date] do %>
              <p class="mt-1 text-sm text-red-600">{@errors[:report_date]}</p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-2">Team *</label>
            <select
              name="report[team_id]"
              value={@form_data.team_id}
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
            >
              <option value="">Select a team</option>
              <%= for team <- @teams do %>
                <option value={team.id} selected={to_string(team.id) == @form_data.team_id}>
                  <%= team.name %> - <%= team.department.name %>
                </option>
              <% end %>
            </select>
            <%= if @errors[:team_id] do %>
              <p class="mt-1 text-sm text-red-600">{@errors[:team_id]}</p>
            <% end %>
          </div>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Summary *</label>
          <textarea
            name="report[summary]"
            rows="3"
            required
            placeholder="Brief summary of the day's activities..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          ><%= @form_data.summary %></textarea>
          <%= if @errors[:summary] do %>
            <p class="mt-1 text-sm text-red-600">{@errors[:summary]}</p>
          <% end %>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Tasks Completed *</label>
          <textarea
            name="report[tasks_completed]"
            rows="4"
            required
            placeholder="List all tasks completed today..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          ><%= @form_data.tasks_completed %></textarea>
          <%= if @errors[:tasks_completed] do %>
            <p class="mt-1 text-sm text-red-600">{@errors[:tasks_completed]}</p>
          <% end %>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Challenges</label>
          <textarea
            name="report[challenges]"
            rows="3"
            placeholder="Any challenges or blockers encountered..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          ><%= @form_data.challenges %></textarea>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Next Day Plans</label>
          <textarea
            name="report[next_day_plans]"
            rows="3"
            placeholder="Plans for tomorrow..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          ><%= @form_data.next_day_plans %></textarea>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t">
          <button
            type="button"
            phx-click="cancel_form"
            class="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <%= if @editing, do: "Update Report", else: "Save Report" %>
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp status_class("draft"), do: "bg-gray-100 text-gray-800"
  defp status_class("submitted"), do: "bg-blue-100 text-blue-800"
  defp status_class("reviewed"), do: "bg-green-100 text-green-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"
end
