defmodule TrialAppWeb.SupervisorLive.Dashboard do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams, Orgs}
  alias TrialAppWeb.SupervisorLive.{ProjectForm, TaskForm, EvaluationForm}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    current_scope = socket.assigns.current_scope
    active_role = Accounts.get_active_role(current_user)

    {:ok,
     socket
     |> assign(:page_title, "Supervisor Dashboard")
     |> assign(:current_user, current_user)
     |> assign(:current_scope, current_scope)
     |> assign(:active_role, active_role)
     |> assign(:selected_project, nil)
     |> assign(:project_tasks, [])
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)
     |> load_data(current_user, active_role)}
  end

  defp load_data(socket, user, "admin") do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)

    # Admin sees ALL projects
    projects = Eams.list_projects()

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats_for_admin())
    |> assign(:recent_activities, load_recent_activities_for_admin())
  end

  defp load_data(socket, user, _role) do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)

    # Supervisor sees only their own
    projects = Eams.list_projects_for_supervisor(user.id)

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats(user))
    |> assign(:recent_activities, load_recent_activities(user))
  end

  # Admin: all data
  defp load_supervisor_stats_for_admin do
    all_tasks = Eams.list_tasks()

    %{
      total_projects: Eams.count_projects(),
      total_attachees: Eams.count_attachees(),
      active_tasks: Enum.count(all_tasks, &(&1.status in ["pending", "in_progress"])),
      pending_reviews: Enum.count(all_tasks, &(&1.status == "submitted")),
      completed_tasks: Enum.count(all_tasks, &(&1.status == "completed"))
    }
  end

  # Supervisor: own data
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

  defp load_recent_activities_for_admin do
    Eams.list_tasks()
    |> Enum.sort_by(& &1.updated_at, {:desc, NaiveDateTime})
    |> Enum.take(10)
    |> Enum.map(&format_activity/1)
  end

  defp load_recent_activities(current_user) do
    Eams.list_tasks_for_supervisor(current_user.id)
    |> Enum.sort_by(& &1.updated_at, {:desc, NaiveDateTime})
    |> Enum.take(10)
    |> Enum.map(&format_activity/1)
  end

  defp format_activity(task) do
    %{
      task_title: task.title,
      project_name: task.project.name,
      assignee_name: task.assignee.user.username || task.assignee.user.email,
      status: task.status,
      updated_at: task.updated_at
    }
  end

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
    {:noreply, assign(socket, :selected_project, nil) |> assign(:project_tasks, [])}
  end

  def handle_event("toggle_project_form", _, socket) do
    {:noreply, assign(socket, :show_project_form, !socket.assigns.show_project_form)}
  end

  def handle_event("toggle_task_form", _, socket) do
    {:noreply, assign(socket, :show_task_form, !socket.assigns.show_task_form)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_project_form, false) |> assign(:show_task_form, false)}
  end

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

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end

  def handle_info({:project_created, _}, socket) do
    user = socket.assigns.current_user
    role = socket.assigns.active_role
    {:noreply, socket |> load_data(user, role) |> put_flash(:info, "Project created!") |> assign(:show_project_form, false)}
  end

  def handle_info({:task_created, _}, socket) do
    user = socket.assigns.current_user
    role = socket.assigns.active_role
    {:noreply, socket |> load_data(user, role) |> put_flash(:info, "Task created!") |> assign(:show_task_form, false)}
  end

  # ─── RENDER ───
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 via-purple-50/30 to-blue-50/20">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="lg:ml-64 p-6 md:p-8">
        <div class="max-w-[1600px] mx-auto space-y-6">

          <!-- Header Section -->
         <div class="relative overflow-hidden bg-purple-400 hover:bg-purple-700 rounded-lg p-4 shadow-xl transition-colors">
         <div class="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImdyaWQiIHdpZHRoPSI2MCIgaGVpZ2h0PSI2MCIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PHBhdGggZD0iTSAxMCAwIEwgMCAwIDAgMTAiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS1vcGFjaXR5PSIwLjA1IiBzdHJva2Utd2lkdGg9IjEiLz48L3BhdHRlcm4+PC9kZWZzPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InVybCgjZ3JpZCkiLz48L3N2Zz4=')] opacity-40"></div>

            <div class="relative flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
              <div class="space-y-3">
                <div class="inline-flex items-center gap-2 px-3 py-1.5 bg-white/10 backdrop-blur-sm rounded-full border border-white/20">
                  <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                  <span class="text-xs font-medium text-white/90">Live Dashboard</span>
                </div>
                <h1 class="text-4xl md:text-4xl font-bold text-white tracking-tight">
                  <%= @organization.name %>
                </h1>
                <div class="flex items-center gap-3 text-white/80">
                  <span class="inline-flex items-center gap-2 px-3 py-1 bg-white/10 backdrop-blur-sm rounded-lg border border-white/20 text-sm font-medium">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                    </svg>
                    <%= @department.name %>
                  </span>
                  <span class="text-sm">Supervisor Dashboard</span>
                </div>
              </div>

              <button phx-click="toggle_project_form" class="group relative px-6 py-3.5 bg-white text-purple-700 hover:bg-purple-50 rounded-xl font-semibold transition-all duration-200 flex items-center gap-2 shadow-lg hover:shadow-xl hover:scale-105">
                <svg class="w-5 h-5 group-hover:rotate-90 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"/>
                </svg>
                New Project
              </button>
            </div>
          </div>

          <!-- Stats Grid -->
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
            <!-- Projects Stat -->
            <div class="group relative bg-white hover:bg-gradient-to-br hover:from-purple-50 hover:to-white rounded-2xl p-6 border border-gray-100 hover:border-purple-200 shadow-sm hover:shadow-md transition-all duration-200">
              <div class="flex items-start justify-between mb-4">
                <div class="p-3 bg-gradient-to-br from-purple-100 to-purple-50 rounded-xl group-hover:scale-110 transition-transform duration-200">
                  <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                  </svg>
                </div>
              </div>
              <div class="space-y-1">
                <p class="text-3xl font-bold text-gray-900"><%= @stats.total_projects %></p>
                <p class="text-sm font-medium text-gray-500">Total Projects</p>
              </div>
            </div>

            <!-- Attachees Stat -->
            <div class="group relative bg-white hover:bg-gradient-to-br hover:from-blue-50 hover:to-white rounded-2xl p-6 border border-gray-100 hover:border-blue-200 shadow-sm hover:shadow-md transition-all duration-200">
              <div class="flex items-start justify-between mb-4">
                <div class="p-3 bg-gradient-to-br from-blue-100 to-blue-50 rounded-xl group-hover:scale-110 transition-transform duration-200">
                  <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                  </svg>
                </div>
              </div>
              <div class="space-y-1">
                <p class="text-3xl font-bold text-gray-900"><%= @stats.total_attachees %></p>
                <p class="text-sm font-medium text-gray-500">Attachees</p>
              </div>
            </div>

            <!-- Active Tasks Stat -->
            <div class="group relative bg-white hover:bg-gradient-to-br hover:from-green-50 hover:to-white rounded-2xl p-6 border border-gray-100 hover:border-green-200 shadow-sm hover:shadow-md transition-all duration-200">
              <div class="flex items-start justify-between mb-4">
                <div class="p-3 bg-gradient-to-br from-green-100 to-green-50 rounded-xl group-hover:scale-110 transition-transform duration-200">
                  <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                  </svg>
                </div>
              </div>
              <div class="space-y-1">
                <p class="text-3xl font-bold text-gray-900"><%= @stats.active_tasks %></p>
                <p class="text-sm font-medium text-gray-500">Active Tasks</p>
              </div>
            </div>

            <!-- Pending Reviews Stat -->
            <div class="group relative bg-white hover:bg-gradient-to-br hover:from-amber-50 hover:to-white rounded-2xl p-6 border border-gray-100 hover:border-amber-200 shadow-sm hover:shadow-md transition-all duration-200">
              <div class="flex items-start justify-between mb-4">
                <div class="p-3 bg-gradient-to-br from-amber-100 to-amber-50 rounded-xl group-hover:scale-110 transition-transform duration-200">
                  <svg class="w-6 h-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
              </div>
              <div class="space-y-1">
                <p class="text-3xl font-bold text-gray-900"><%= @stats.pending_reviews %></p>
                <p class="text-sm font-medium text-gray-500">Pending Reviews</p>
              </div>
            </div>

            <!-- Completed Stat -->
            <div class="group relative bg-white hover:bg-gradient-to-br hover:from-emerald-50 hover:to-white rounded-2xl p-6 border border-gray-100 hover:border-emerald-200 shadow-sm hover:shadow-md transition-all duration-200">
              <div class="flex items-start justify-between mb-4">
                <div class="p-3 bg-gradient-to-br from-emerald-100 to-emerald-50 rounded-xl group-hover:scale-110 transition-transform duration-200">
                  <svg class="w-6 h-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
              </div>
              <div class="space-y-1">
                <p class="text-3xl font-bold text-gray-900"><%= @stats.completed_tasks %></p>
                <p class="text-sm font-medium text-gray-500">Completed</p>
              </div>
            </div>
          </div>

          <!-- Quick Actions -->
          <div class="flex flex-wrap gap-3">
            <.link navigate={~p"/supervisor/projects"} class="group px-5 py-2.5 bg-white hover:bg-purple-50 rounded-xl border border-gray-200 hover:border-purple-300 text-gray-700 hover:text-purple-700 font-medium transition-all duration-200 flex items-center gap-2 shadow-sm hover:shadow">
              <svg class="w-4 h-4 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
              </svg>
              View All Projects
            </.link>

            <.link navigate={~p"/supervisor/tasks"} class="group px-5 py-2.5 bg-white hover:bg-blue-50 rounded-xl border border-gray-200 hover:border-blue-300 text-gray-700 hover:text-blue-700 font-medium transition-all duration-200 flex items-center gap-2 shadow-sm hover:shadow">
              <svg class="w-4 h-4 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
              </svg>
              Manage Tasks
            </.link>

            <.link navigate={~p"/supervisor/attachees"} class="group px-5 py-2.5 bg-white hover:bg-green-50 rounded-xl border border-gray-200 hover:border-green-300 text-gray-700 hover:text-green-700 font-medium transition-all duration-200 flex items-center gap-2 shadow-sm hover:shadow">
              <svg class="w-4 h-4 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
              View Attachees
            </.link>
          </div>

          <!-- Projects Section -->
          <div class="bg-white rounded-1xl border border-gray-100 shadow-sm overflow-hidden">
            <div class="px-6 py-5 border-b border-gray-100 bg-gradient-to-r from-gray-50 to-white">
              <div class="flex items-center justify-between">
                <h2 class="text-xl font-bold text-gray-900">My Projects</h2>
                <span class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-sm font-semibold">
                  <%= length(@projects) %> Total
                </span>
              </div>
            </div>

            <div class="p-6">
              <%= if @projects == [] do %>
                <div class="text-center py-16">
                  <div class="inline-flex items-center justify-center w-20 h-20 bg-gray-100 rounded-full mb-6">
                    <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                    </svg>
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900 mb-2">No projects yet</h3>
                  <p class="text-gray-500 mb-6 max-w-sm mx-auto">Get started by creating your first project and start managing your team's work.</p>
                  <button phx-click="toggle_project_form" class="inline-flex items-center gap-2 px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-semibold transition-all duration-200 shadow-lg hover:shadow-xl">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                    </svg>
                    Create Your First Project
                  </button>
                </div>
              <% else %>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                  <%= for project <- @projects do %>
                    <div
                      phx-click="view_project_tasks"
                      phx-value-id={project.id}
                      class={"group relative p-5 rounded-2xl border-2 transition-all duration-200 cursor-pointer hover:shadow-lg #{if is_overdue?(project), do: "border-red-200 bg-gradient-to-br from-red-50 to-white hover:border-red-300", else: "border-gray-200 bg-white hover:border-purple-300 hover:shadow-purple-100"}"}
                    >
                      <div class="flex flex-col h-full space-y-4">
                        <!-- Header -->
                        <div class="flex items-start justify-between gap-3">
                          <h3 class="text-lg font-bold text-gray-900 group-hover:text-purple-700 transition-colors line-clamp-2 flex-1">
                            <%= project.name %>
                          </h3>
                          <span class="px-2.5 py-1 bg-gray-100 text-gray-600 rounded-lg text-xs font-bold flex-shrink-0">
                            <%= project.code %>
                          </span>
                        </div>

                        <!-- Status Badge -->
                        <%= if is_overdue?(project) do %>
                          <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-red-100 text-red-700 rounded-lg text-xs font-semibold w-fit">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                            </svg>
                            Overdue
                          </span>
                        <% end %>

                        <!-- Description -->
                        <p class="text-sm text-gray-600 line-clamp-2 flex-1 leading-relaxed">
                          <%= project.description %>
                        </p>

                        <!-- Dates -->
                        <div class="space-y-2.5 pt-3 border-t border-gray-100">
                          <div class="flex items-center gap-2 text-sm text-gray-600">
                            <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                            <span class="font-medium">Start:</span>
                            <span><%= format_date(project.starts_on) %></span>
                          </div>
                          <div class={"flex items-center gap-2 text-sm #{if is_overdue?(project), do: "text-red-600 font-semibold", else: "text-gray-600"}"}>
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            </svg>
                            <span class="font-medium">Due:</span>
                            <span><%= format_due_date(project.ends_on) %></span>
                          </div>
                        </div>
                      </div>

                      <!-- Hover Arrow -->
                      <div class="absolute top-5 right-5 w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                        <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                        </svg>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Recent Activities -->
          <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div class="px-6 py-5 border-b border-gray-100 bg-gradient-to-r from-gray-50 to-white">
              <h2 class="text-xl font-bold text-gray-900">Recent Activities</h2>
            </div>

            <div class="p-6">
              <%= if @recent_activities == [] do %>
                <div class="text-center py-12">
                  <div class="inline-flex items-center justify-center w-16 h-16 bg-gray-100 rounded-full mb-4">
                    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                  </div>
                  <p class="text-gray-500 font-medium">No recent activities</p>
                </div>
              <% else %>
                <div class="relative h-96 overflow-hidden rounded-xl">
                  <div class="absolute inset-0 space-y-3 animate-slide-vertical" style={"animation-duration: #{length(@recent_activities) * 3}s"}>
                    <%= for activity <- @recent_activities ++ @recent_activities do %>
                      <div class="group p-4 bg-gradient-to-r from-gray-50 to-white hover:from-purple-50 hover:to-white rounded-xl border border-gray-100 hover:border-purple-200 transition-all duration-200">
                        <div class="flex items-start gap-3 mb-3">
                          <div class={"w-2.5 h-2.5 rounded-full mt-1.5 flex-shrink-0 #{status_indicator(activity.status)}"}></div>
                          <div class="flex-1 min-w-0">
                            <p class="font-semibold text-gray-900 group-hover:text-purple-700 transition-colors truncate">
                              <%= activity.task_title %>
                            </p>
                            <p class="text-sm text-gray-500 mt-0.5">
                              <%= activity.project_name %>
                            </p>
                          </div>
                        </div>
                        <div class="flex items-center justify-between gap-3 pl-5">
                          <p class="text-sm text-gray-600 truncate flex-1">
                            <%= activity.assignee_name %>
                          </p>
                          <div class="flex items-center gap-2 flex-shrink-0">
                            <span class={"px-2.5 py-1 text-xs rounded-lg font-semibold #{status_color(activity.status)}"}>
                              <%= format_status(activity.status) %>
                            </span>
                            <span class="text-xs text-gray-400 font-medium">
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

          <!-- Announcements Widget -->
          <.live_component
            module={TrialAppWeb.AnnouncementsWidget}
            id="supervisor-announcements"
            current_user={@current_user}
            active_role={@active_role}
          />
        </div>
      </div>

      <style>
        @keyframes slide-vertical {
          0% { transform: translateY(0); }
          100% { transform: translateY(-50%); }
        }
        .animate-slide-vertical {
          animation: slide-vertical linear infinite;
        }
      </style>

      <!-- Modals -->
      <%= if @selected_project do %>
        <!-- Project modal unchanged -->
      <% end %>

      <.live_component :if={@show_project_form} module={ProjectForm} id="project-form" current_user={@current_user} department={@department} />
      <.live_component :if={@show_task_form} module={TaskForm} id="task-form" project={@selected_project} />
    </div>
    """
  end
  # ─── HELPERS (unchanged) ───
  defp is_overdue?(project), do: project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt
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

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("in_progress"), do: "bg-blue-100 text-blue-800"
  defp status_color("completed"), do: "bg-green-100 text-green-800"
  defp status_color("submitted"), do: "bg-purple-100 text-purple-800"
  defp status_color("rejected"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_date(nil), do: "Not set"
  defp format_date(date), do: Calendar.strftime(date, "%b %d, %Y")

  defp status_indicator("pending"), do: "bg-yellow-500"
  defp status_indicator("in_progress"), do: "bg-blue-500"
  defp status_indicator("completed"), do: "bg-green-500"
  defp status_indicator("submitted"), do: "bg-purple-500"
  defp status_indicator("rejected"), do: "bg-red-500"
  defp status_indicator(_), do: "bg-gray-400"

  defp format_status(status) do
    status |> String.replace("_", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  end
end
