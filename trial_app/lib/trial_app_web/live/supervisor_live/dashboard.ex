defmodule TrialAppWeb.SupervisorLive.Dashboard do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams, Orgs}
  alias TrialAppWeb.SupervisorLive.{ProjectForm, TaskForm, EvaluationForm}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    current_scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Supervisor Dashboard")
     |> assign(:current_user, current_user)
     |> assign(:current_scope, current_scope)
     |> assign(:selected_project, nil)
     |> assign(:project_tasks, [])
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)
     |> load_data(current_user)}
  end

  defp load_data(socket, user) do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)

    # Get all projects supervised by this user
    projects = Eams.list_projects_for_supervisor(user.id)

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats(user))
    |> assign(:recent_activities, load_recent_activities(user))
  end

  # ──────────────────────────────────────────────────────────────────────
  # EVENT HANDLERS
  # ──────────────────────────────────────────────────────────────────────
  @impl true
  def handle_event("view_project_tasks", %{"id" => id}, socket) do
    project = Eams.get_project!(id, preloads: [:program, :department, :organization])
    tasks = Eams.list_tasks_for_project(id)

    {:noreply,
     socket
     |> assign(:selected_project, project)
     |> assign(:project_tasks, tasks)}
  end

  def handle_event("close_project_view", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_project, nil)
     |> assign(:project_tasks, [])}
  end

  def handle_event("toggle_project_form", _, socket) do
    {:noreply, assign(socket, :show_project_form, !socket.assigns.show_project_form)}
  end

  def handle_event("toggle_task_form", _, socket) do
    {:noreply, assign(socket, :show_task_form, !socket.assigns.show_task_form)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)}
  end

  # ──────────────────────────────────────────────────────────────────────
  # INFO MESSAGES
  # ──────────────────────────────────────────────────────────────────────
  @impl true
  def handle_info({:switch_role, new_role}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.switch_user_role(user, new_role) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        redirect_path = case new_role do
          "admin" -> ~p"/admin/dashboard"
          "supervisor" -> ~p"/supervisor/dashboard"
          "attachee" -> ~p"/attachee"
          "manager" -> ~p"/dashboard"
          "employee" -> ~p"/dashboard"
          _ -> ~p"/dashboard"
        end

        {:noreply,
         socket
         |> assign(:current_scope, updated_scope)
         |> put_flash(:info, "Switched to #{new_role} role")
         |> push_navigate(to: redirect_path)}

      {:error, :unauthorized_role} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to switch to that role")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end

  def handle_info({:project_created, _project}, socket) do
    user = socket.assigns.current_user
    {:noreply,
     socket
     |> load_data(user)
     |> put_flash(:info, "Project created successfully!")
     |> assign(:show_project_form, false)}
  end

  def handle_info({:task_created, _}, socket) do
    user = socket.assigns.current_user
    {:noreply,
     socket
     |> load_data(user)
     |> put_flash(:info, "Task created successfully!")
     |> assign(:show_task_form, false)}
  end

  # ──────────────────────────────────────────────────────────────────────
  # STATS & ACTIVITIES
  # ──────────────────────────────────────────────────────────────────────
  defp load_supervisor_stats(current_user) do
    all_tasks = Eams.list_tasks_for_supervisor(current_user.id)

    %{
      total_projects: Eams.count_projects_for_supervisor(current_user.id),
      total_attachees: Eams.count_attachees_under_supervisor(current_user.id),
      active_tasks: Enum.count(all_tasks, &(&1.status in ["pending", "in_progress"])),
      pending_reviews: Enum.count(all_tasks, &(&1.status == "submitted")),
      completed_tasks: Enum.count(all_tasks, &(&1.status == "completed"))
    }
  end

  defp load_recent_activities(current_user) do
    all_tasks = Eams.list_tasks_for_supervisor(current_user.id)

    all_tasks
    |> Enum.sort_by(& &1.updated_at, {:desc, NaiveDateTime})
    |> Enum.take(10)
    |> Enum.map(fn task ->
      %{
        task_title: task.title,
        project_name: task.project.name,
        assignee_name: task.assignee.user.username || task.assignee.user.email,
        status: task.status,
        updated_at: task.updated_at
      }
    end)
  end

  defp is_overdue?(project) do
    project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt
  end

  defp days_until_due(project) do
    if project.ends_on do
      Date.diff(project.ends_on, Date.utc_today())
    else
      nil
    end
  end

  defp format_due_date(nil), do: "No deadline"
  defp format_due_date(date) do
    days = Date.diff(date, Date.utc_today())
    cond do
      days < 0 -> "#{abs(days)} days overdue"
      days == 0 -> "Due today"
      days == 1 -> "Due tomorrow"
      days <= 7 -> "Due in #{days} days"
      true -> Calendar.strftime(date, "%b %d, %Y")
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # RENDER
  # ──────────────────────────────────────────────────────────────────────
  @impl true
def render(assigns) do
  ~H"""
  <div class="min-h-screen bg-white">
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

    <div class="lg:ml-64 p-8">
      <div class="max-w-7xl mx-auto space-y-8">
        <!-- Organization Info Banner -->
        <div class="bg-gradient-to-r from-purple-600 to-purple-700 rounded-2xl p-6 text-white shadow-lg">
          <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
            <div>
              <h2 class="text-2xl font-bold mb-2"><%= @organization.name %></h2>
              <div class="flex items-center gap-4 text-sm">
                <span class="bg-white/20 px-3 py-1 rounded-full border border-white/40">
                  <%= @department.name %>
                </span>
                <span class="opacity-90">Supervisor Dashboard</span>
              </div>
            </div>
            <button phx-click="toggle_project_form" class="px-4 py-2 bg-white text-purple-600 hover:bg-gray-100 rounded-lg font-medium transition flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              New Project
            </button>
          </div>
        </div>

        <!-- Stats Cards -->
        <div class="grid grid-cols-1 md:grid-cols-5 gap-6">
          <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
            <div class="flex items-center justify-between mb-2">
              <div class="w-10 h-10 rounded-xl bg-purple-100 flex items-center justify-center">
                <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                </svg>
              </div>
              <span class="text-xl font-bold text-gray-900"><%= @stats.total_projects %></span>
            </div>
            <p class="text-sm text-gray-600">Projects</p>
          </div>

          <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
            <div class="flex items-center justify-between mb-2">
              <div class="w-10 h-10 rounded-xl bg-blue-100 flex items-center justify-center">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
              </div>
              <span class="text-xl font-bold text-gray-900"><%= @stats.total_attachees %></span>
            </div>
            <p class="text-sm text-gray-600">Attachees</p>
          </div>

          <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
            <div class="flex items-center justify-between mb-2">
              <div class="w-10 h-10 rounded-xl bg-green-100 flex items-center justify-center">
                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                </svg>
              </div>
              <span class="text-xl font-bold text-gray-900"><%= @stats.active_tasks %></span>
            </div>
            <p class="text-sm text-gray-600">Active Tasks</p>
          </div>

          <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
            <div class="flex items-center justify-between mb-2">
              <div class="w-10 h-10 rounded-xl bg-yellow-100 flex items-center justify-center">
                <svg class="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <span class="text-xl font-bold text-gray-900"><%= @stats.pending_reviews %></span>
            </div>
            <p class="text-sm text-gray-600">Pending Reviews</p>
          </div>

          <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
            <div class="flex items-center justify-between mb-2">
              <div class="w-10 h-10 rounded-xl bg-emerald-100 flex items-center justify-center">
                <svg class="w-5 h-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
              </div>
              <span class="text-xl font-bold text-gray-900"><%= @stats.completed_tasks %></span>
            </div>
            <p class="text-sm text-gray-600">Completed</p>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="flex gap-3">
          <.link navigate={~p"/supervisor/projects"} class="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition">
            View All Projects
          </.link>
          <.link navigate={~p"/supervisor/tasks"} class="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition">
            Manage Tasks
          </.link>
          <.link navigate={~p"/supervisor/attachees"} class="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition">
            View Attachees
          </.link>
        </div>

        <!-- Projects Grid - Better Layout -->
        <div class="bg-white shadow rounded-xl border border-gray-200 overflow-hidden">
          <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-semibold text-gray-800">My Projects</h2>
          </div>
          <div class="p-6">
            <%= if @projects == [] do %>
              <div class="text-center py-12">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                <p class="text-gray-500 mb-4">No projects yet</p>
                <button phx-click="toggle_project_form" class="px-4 py-2 rounded-lg bg-purple-600 text-white hover:bg-purple-700 transition">
                  Create Your First Project
                </button>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for project <- @projects do %>
                  <div class={"p-4 rounded-lg border-2 transition-all hover:shadow-md cursor-pointer #{if is_overdue?(project), do: "border-red-500 bg-red-50", else: "border-gray-200 hover:border-purple-300"}"}
                       phx-click="view_project_tasks"
                       phx-value-id={project.id}>
                    <div class="flex flex-col h-full">
                      <div class="flex items-center gap-2 mb-3">
                        <h3 class="text-lg font-semibold text-gray-900 flex-1"><%= project.name %></h3>
                        <span class="px-2 py-1 text-xs bg-gray-100 text-gray-600 rounded-full"><%= project.code %></span>
                      </div>

                      <%= if is_overdue?(project) do %>
                        <span class="px-2 py-1 text-xs bg-red-100 text-red-700 rounded-full w-fit mb-2">Overdue</span>
                      <% end %>

                      <p class="text-sm text-gray-600 mb-4 line-clamp-2 flex-1"><%= project.description %></p>

                      <div class="space-y-2 text-sm text-gray-500">
                        <div class="flex items-center gap-2">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          <span>Starts: <%= Calendar.strftime(project.starts_on, "%b %d, %Y") %></span>
                        </div>
                        <div class={"flex items-center gap-2 #{if is_overdue?(project), do: "text-red-600 font-medium"}"}>
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                          </svg>
                          <span><%= format_due_date(project.ends_on) %></span>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Recent Activities - At the Bottom -->
        <div class="bg-white shadow rounded-xl border border-gray-200 overflow-hidden">
          <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-semibold text-gray-800">Recent Activities</h2>
          </div>
          <div class="p-6">
            <%= if @recent_activities == [] do %>
              <div class="text-center py-8">
                <p class="text-gray-500">No recent activities</p>
              </div>
            <% else %>
              <div class="relative h-80 overflow-hidden">
                <!-- Auto-sliding container -->
                <div class="absolute inset-0 space-y-3 animate-slide-vertical"
                     style={"animation-duration: #{length(@recent_activities) * 3}s"}>
                  <%= for activity <- @recent_activities do %>
                    <div class="p-4 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition">
                      <div class="flex items-start gap-3 mb-2">
                        <div class={"w-2 h-2 rounded-full mt-2 #{status_indicator(activity.status)}"}></div>
                        <div class="flex-1">
                          <p class="font-medium text-gray-900"><%= activity.task_title %></p>
                          <p class="text-sm text-gray-500 mt-1"><%= activity.project_name %></p>
                        </div>
                      </div>
                      <div class="flex justify-between items-center">
                        <p class="text-sm text-gray-600"><%= activity.assignee_name %></p>
                        <div class="flex items-center gap-2">
                          <span class={"px-2.5 py-1 text-xs rounded-full font-medium #{status_color(activity.status)}"}>
                            <%= format_status(activity.status) %>
                          </span>
                          <span class="text-xs text-gray-400">
                            <%= Timex.from_now(activity.updated_at) %>
                          </span>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <!-- Duplicate for seamless looping -->
                  <%= for activity <- @recent_activities do %>
                    <div class="p-4 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition">
                      <div class="flex items-start gap-3 mb-2">
                        <div class={"w-2 h-2 rounded-full mt-2 #{status_indicator(activity.status)}"}></div>
                        <div class="flex-1">
                          <p class="font-medium text-gray-900"><%= activity.task_title %></p>
                          <p class="text-sm text-gray-500 mt-1"><%= activity.project_name %></p>
                        </div>
                      </div>
                      <div class="flex justify-between items-center">
                        <p class="text-sm text-gray-600"><%= activity.assignee_name %></p>
                        <div class="flex items-center gap-2">
                          <span class={"px-2.5 py-1 text-xs rounded-full font-medium #{status_color(activity.status)}"}>
                            <%= format_status(activity.status) %>
                          </span>
                          <span class="text-xs text-gray-400">
                            <%= Timex.from_now(activity.updated_at) %>
                          </span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <!-- Add this CSS for auto-sliding animation -->
    <style>
      @keyframes slide-vertical {
        0% { transform: translateY(0); }
        100% { transform: translateY(-50%); }
      }
      .animate-slide-vertical {
        animation: slide-vertical linear infinite;
      }
    </style>

    <!-- Project Tasks Modal -->
    <%= if @selected_project do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" phx-click="close_project_view">
        <div class="bg-white rounded-xl shadow-lg w-full max-w-4xl mx-4" phx-click="stop_propagation">
          <div class="flex justify-between items-start p-6 border-b border-gray-200">
            <div>
              <h3 class="text-xl font-semibold text-gray-800"><%= @selected_project.name %></h3>
              <p class="text-sm text-gray-500 mt-1"><%= @selected_project.description %></p>
            </div>
            <button phx-click="close_project_view" class="p-2 hover:bg-gray-100 rounded-lg">
              <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="p-6">
            <h4 class="font-semibold text-gray-800 mb-4">Tasks in this Project</h4>

            <%= if @project_tasks == [] do %>
              <div class="text-center py-8">
                <p class="text-gray-500">No tasks in this project yet</p>
              </div>
            <% else %>
              <div class="space-y-3 max-h-96 overflow-y-auto">
                <%= for task <- @project_tasks do %>
                  <div class="p-4 bg-gray-50 rounded-lg border border-gray-200">
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <h5 class="font-semibold text-gray-900"><%= task.title %></h5>
                        <p class="text-sm text-gray-600 mt-1"><%= task.description %></p>

                        <div class="flex gap-4 mt-3 text-sm text-gray-500">
                          <div>
                            <span class="font-medium">Assigned to: </span>
                            <span class="ml-1"><%= task.assignee.user.username || task.assignee.user.email %></span>
                          </div>
                          <%= if task.due_on do %>
                            <div>
                              <span class="font-medium">Due: </span>
                              <span class="ml-1"><%= Calendar.strftime(task.due_on, "%b %d, %Y") %></span>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <div class="text-right">
                        <span class={"px-2.5 py-0.5 text-xs rounded-full font-medium #{status_color(task.status)}"}>
                          <%= format_status(task.status) %>
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="flex justify-end p-6 border-t border-gray-200">
            <button phx-click="close_project_view" class="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition">
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Modals -->
    <.live_component
      :if={@show_project_form}
      module={ProjectForm}
      id="project-form"
      current_user={@current_user}
      department={@department}
    />

    <.live_component
      :if={@show_task_form}
      module={TaskForm}
      id="task-form"
      project={@selected_project}
    />
  </div>
  """
end
  # ──────────────────────────────────────────────────────────────────────
  # HELPERS
  # ──────────────────────────────────────────────────────────────────────
  defp status_color("pending"), do: "badge-warning"
  defp status_color("in_progress"), do: "badge-info"
  defp status_color("completed"), do: "badge-success"
  defp status_color("submitted"), do: "badge-primary"
  defp status_color("rejected"), do: "badge-error"
  defp status_color(_), do: "badge-ghost"

  defp status_indicator("pending"), do: "bg-warning"
  defp status_indicator("in_progress"), do: "bg-info"
  defp status_indicator("completed"), do: "bg-success"
  defp status_indicator("submitted"), do: "bg-primary"
  defp status_indicator("rejected"), do: "bg-error"
  defp status_indicator(_), do: "bg-base-content/20"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
