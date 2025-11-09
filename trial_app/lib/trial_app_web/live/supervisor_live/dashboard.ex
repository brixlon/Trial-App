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
    <div class="min-h-screen bg-base-200">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="lg:ml-64 p-8">
        <div class="max-w-7xl mx-auto">
          <!-- Organization Info Banner -->
          <div class="card bg-gradient-to-r from-primary to-secondary text-primary-content shadow-xl mb-6">
            <div class="card-body">
              <div class="flex justify-between items-center">
                <div>
                  <h2 class="text-3xl font-bold mb-2"><%= @organization.name %></h2>
                  <div class="flex items-center gap-4 text-lg">
                    <span class="badge badge-lg bg-white/20 border-white/40">
                      📂 <%= @department.name %>
                    </span>
                    <span class="opacity-90">Supervisor Dashboard</span>
                  </div>
                </div>
                <div class="text-right">
                  <.button phx-click="toggle_project_form" class="btn-accent btn-lg">
                    + New Project
                  </.button>
                </div>
              </div>
            </div>
          </div>

          <!-- Stats Cards -->
          <div class="grid grid-cols-1 md:grid-cols-5 gap-6 mb-8">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Projects</p>
                <p class="text-3xl font-bold text-primary"><%= @stats.total_projects %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Attachees</p>
                <p class="text-3xl font-bold text-secondary"><%= @stats.total_attachees %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Active Tasks</p>
                <p class="text-3xl font-bold text-info"><%= @stats.active_tasks %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Pending Reviews</p>
                <p class="text-3xl font-bold text-warning"><%= @stats.pending_reviews %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Completed</p>
                <p class="text-3xl font-bold text-success"><%= @stats.completed_tasks %></p>
              </div>
            </div>
          </div>

          <!-- Quick Actions -->
          <div class="flex gap-4 mb-6">
            <.link navigate={~p"/supervisor/projects"} class="btn btn-outline">
              View All Projects
            </.link>
            <.link navigate={~p"/supervisor/tasks"} class="btn btn-outline">
              Manage Tasks
            </.link>
            <.link navigate={~p"/supervisor/attachees"} class="btn btn-outline">
              View Attachees
            </.link>
          </div>

          <!-- Main Content Grid -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Projects List -->
            <div class="lg:col-span-2">
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title text-2xl mb-4">My Projects</h2>

                  <div :if={@projects == []} class="text-center py-12">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-base-content/20 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                    <p class="text-base-content/50 mb-4">No projects yet</p>
                    <.button phx-click="toggle_project_form" class="btn-primary">
                      Create Your First Project
                    </.button>
                  </div>

                  <div class="space-y-4" :if={@projects != []}>
                    <%= for project <- @projects do %>
                      <div class={"card border-2 transition-all hover:shadow-lg cursor-pointer #{if is_overdue?(project), do: "border-error bg-error/5", else: "border-base-300 hover:border-primary"}"}>
                        <div class="card-body p-4">
                          <div class="flex justify-between items-start">
                            <div class="flex-1">
                              <div class="flex items-center gap-3 mb-2">
                                <h3 class="text-lg font-bold"><%= project.name %></h3>
                                <span class="badge badge-sm"><%= project.code %></span>
                                <%= if is_overdue?(project) do %>
                                  <span class="badge badge-error badge-sm">Overdue</span>
                                <% end %>
                              </div>
                              <p class="text-sm text-base-content/70 mb-3"><%= project.description %></p>

                              <div class="flex gap-4 text-sm">
                                <div class="flex items-center gap-1">
                                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                  <span>Starts: <%= Calendar.strftime(project.starts_on, "%b %d, %Y") %></span>
                                </div>
                                <div class={"flex items-center gap-1 #{if is_overdue?(project), do: "text-error font-bold"}"}>
                                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                                  </svg>
                                  <span><%= format_due_date(project.ends_on) %></span>
                                </div>
                              </div>
                            </div>

                            <div class="flex flex-col gap-2">
                              <button
                                phx-click="view_project_tasks"
                                phx-value-id={project.id}
                                class="btn btn-primary btn-sm"
                              >
                                View Tasks
                              </button>
                            </div>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <!-- Recent Activities -->
            <div class="lg:col-span-1">
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title text-xl mb-4">Recent Activities</h2>

                  <div :if={@recent_activities == []} class="text-center py-8">
                    <p class="text-base-content/50">No recent activities</p>
                  </div>

                  <div class="space-y-3 max-h-[600px] overflow-y-auto" :if={@recent_activities != []}>
                    <%= for activity <- @recent_activities do %>
                      <div class="p-3 bg-base-200 rounded-lg hover:bg-base-300 transition">
                        <div class="flex items-start gap-2 mb-2">
                          <div class={"w-2 h-2 rounded-full mt-1.5 #{status_indicator(activity.status)}"}></div>
                          <div class="flex-1">
                            <p class="font-medium text-sm"><%= activity.task_title %></p>
                            <p class="text-xs text-base-content/70"><%= activity.project_name %></p>
                          </div>
                        </div>
                        <div class="flex justify-between items-center">
                          <p class="text-xs text-base-content/60"><%= activity.assignee_name %></p>
                          <div class="flex items-center gap-2">
                            <span class={"badge badge-xs #{status_color(activity.status)}"}>
                              <%= format_status(activity.status) %>
                            </span>
                            <span class="text-xs text-base-content/50">
                              <%= Timex.from_now(activity.updated_at) %>
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Project Tasks Modal -->
      <%= if @selected_project do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-4xl">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h3 class="font-bold text-2xl"><%= @selected_project.name %></h3>
                <p class="text-sm text-base-content/70 mt-1"><%= @selected_project.description %></p>
              </div>
              <button phx-click="close_project_view" class="btn btn-sm btn-circle btn-ghost">✕</button>
            </div>

            <div class="divider"></div>

            <div class="mb-4">
              <h4 class="font-bold text-lg mb-3">Tasks in this Project</h4>

              <%= if @project_tasks == [] do %>
                <div class="text-center py-8">
                  <p class="text-base-content/50">No tasks in this project yet</p>
                </div>
              <% else %>
                <div class="space-y-3 max-h-96 overflow-y-auto">
                  <%= for task <- @project_tasks do %>
                    <div class="card bg-base-200 shadow">
                      <div class="card-body p-4">
                        <div class="flex justify-between items-start">
                          <div class="flex-1">
                            <h5 class="font-bold"><%= task.title %></h5>
                            <p class="text-sm text-base-content/70 mt-1"><%= task.description %></p>

                            <div class="flex gap-4 mt-3 text-sm">
                              <div>
                                <span class="font-medium">Assigned to:</span>
                                <span class="ml-1"><%= task.assignee.user.username || task.assignee.user.email %></span>
                              </div>
                              <%= if task.due_on do %>
                                <div>
                                  <span class="font-medium">Due:</span>
                                  <span class="ml-1"><%= Calendar.strftime(task.due_on, "%b %d, %Y") %></span>
                                </div>
                              <% end %>
                            </div>
                          </div>

                          <div class="text-right">
                            <span class={"badge #{status_color(task.status)}"}>
                              <%= format_status(task.status) %>
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="modal-action">
              <button phx-click="close_project_view" class="btn">Close</button>
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
