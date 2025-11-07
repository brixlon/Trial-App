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
     |> assign(:selected_attachee, nil)
     |> assign(:attachees, [])
     |> assign(:attachee_tasks, [])
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)
     |> assign(:show_evaluation_form, false)
     |> load_data(current_user)}
  end

  defp load_data(socket, user) do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)
    programs = Eams.list_programs_by_department(dept.id)

    projects =
      if programs == [] do
        []
      else
        program_ids = Enum.map(programs, & &1.id)
        Eams.list_projects_by_programs(program_ids)
      end

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:programs, programs)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats(user))
    |> assign(:recent_activities, load_recent_activities(user))
  end

  # ──────────────────────────────────────────────────────────────────────
  # EVENT HANDLERS
  # ──────────────────────────────────────────────────────────────────────
  @impl true
  def handle_event("select_project", %{"id" => id}, socket) do
    project = Eams.get_project!(id, preloads: [:program, :department, :organization])
    attachees = Eams.list_attachees_in_project(id) || []

    {:noreply,
     socket
     |> assign(:selected_project, project)
     |> assign(:attachees, attachees)
     |> assign(:selected_attachee, nil)
     |> assign(:attachee_tasks, [])}
  end

  def handle_event("select_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id, preloads: [:user, :department, :organization])
    tasks = Eams.list_tasks_for_attachee(attachee.id)

    {:noreply,
     socket
     |> assign(:selected_attachee, attachee)
     |> assign(:attachee_tasks, tasks)}
  end

  def handle_event("toggle_project_form", _, socket) do
    {:noreply, assign(socket, :show_project_form, !socket.assigns.show_project_form)}
  end

  def handle_event("toggle_task_form", _, socket) do
    {:noreply, assign(socket, :show_task_form, !socket.assigns.show_task_form)}
  end

  def handle_event("toggle_evaluation_form", _, socket) do
    {:noreply, assign(socket, :show_evaluation_form, !socket.assigns.show_evaluation_form)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_attachee, nil)
     |> assign(:attachee_tasks, [])
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)
     |> assign(:show_evaluation_form, false)}
  end

  # ──────────────────────────────────────────────────────────────────────
  # INFO MESSAGES
  # ──────────────────────────────────────────────────────────────────────
  @impl true
  def handle_info({:switch_role, new_role}, socket) do
    TrialAppWeb.Live.Helpers.RoleSwitcher.handle_role_switch(socket, new_role)
  end

  def handle_info({:project_created, project}, socket) do
    updated_projects = [project | socket.assigns.projects] |> Enum.uniq_by(& &1.id)

    {:noreply,
     socket
     |> assign(:projects, updated_projects)
     |> put_flash(:info, "Project created!")}
  end

  def handle_info({:task_created, _}, socket) do
    user = socket.assigns.current_user
    {:noreply, load_data(socket, user)}
  end

  def handle_info({:evaluation_submitted, _}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Evaluation submitted!")
     |> assign(:show_evaluation_form, false)}
  end

  # ──────────────────────────────────────────────────────────────────────
  # STATS & ACTIVITIES
  # ──────────────────────────────────────────────────────────────────────
  defp load_supervisor_stats(current_user) do
    %{
      total_attachees: Eams.count_attachees_under_supervisor(current_user.id),
      active_tasks: Eams.count_active_tasks_for_supervisor(current_user.id),
      pending_reviews: Eams.count_pending_task_reviews(current_user.id),
      completed_this_week: Eams.count_completed_tasks_this_week(current_user.id)
    }
  end

  defp load_recent_activities(current_user) do
    Eams.list_recent_activities_for_supervisor(current_user.id, limit: 10)
  end

  # ──────────────────────────────────────────────────────────────────────
  # RENDER
  # ──────────────────────────────────────────────────────────────────────
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="lg:ml-64 p-8">
        <div class="max-w-7xl mx-auto">
          <!-- Breadcrumb -->
          <div class="text-sm breadcrumbs mb-6" :if={@programs != []}>
            <ul>
              <li><%= @organization.name %></li>
              <li><%= @department.name %></li>
              <li><%= hd(@programs).name %></li>
            </ul>
          </div>

          <!-- Header -->
          <div class="flex justify-between items-center mb-8">
            <div>
              <h1 class="text-3xl font-bold">Supervisor Dashboard</h1>
              <p class="text-base-content/70">Manage projects, assign tasks, evaluate performance.</p>
            </div>
            <div class="flex gap-3">
              <.button phx-click="toggle_project_form" class="btn-primary">+ New Project</.button>
              <.button
                phx-click="toggle_task_form"
                :if={@selected_project && @attachees != []}
                class="btn-secondary"
              >
                + Assign Task
              </.button>
            </div>
          </div>

          <!-- Stats Cards -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Total Attachees</p>
                <p class="text-3xl font-bold text-primary"><%= @stats.total_attachees %></p>
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
                <p class="text-sm text-base-content/70">Completed This Week</p>
                <p class="text-3xl font-bold text-success"><%= @stats.completed_this_week %></p>
              </div>
            </div>
          </div>

          <!-- Main Grid -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Projects List -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Projects</h2>

                <div :if={@projects == []} class="text-center py-8">
                  <p class="text-base-content/50">No projects yet</p>
                  <.button phx-click="toggle_project_form" class="mt-4 btn-sm">Create First Project</.button>
                </div>

                <div class="space-y-2 max-h-96 overflow-y-auto" :if={@projects != []}>
                  <%= for project <- @projects do %>
                    <div
                      phx-click="select_project"
                      phx-value-id={project.id}
                      class={"p-3 rounded-lg cursor-pointer transition-all #{if @selected_project && @selected_project.id == project.id, do: "bg-primary text-white shadow-md", else: "hover:bg-base-200"}"}
                    >
                      <p class="font-medium"><%= project.name %></p>
                      <p class="text-sm opacity-70"><%= project.program.name %></p>
                      <p class="text-xs opacity-60">Code: <%= project.code %></p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Attachees in Selected Project -->
            <div class="card bg-base-100 shadow-xl" :if={@selected_project}>
              <div class="card-body">
                <h2 class="card-title">Attachees in <%= @selected_project.name %></h2>

                <div :if={@attachees == []} class="text-center py-8">
                  <p class="text-base-content/50">No attachees assigned</p>
                </div>

                <div class="space-y-2 max-h-80 overflow-y-auto" :if={@attachees != []}>
                  <%= for att <- @attachees do %>
                    <div
                      phx-click="select_attachee"
                      phx-value-id={att.id}
                      class={"p-3 rounded-lg cursor-pointer transition-all #{if @selected_attachee && @selected_attachee.id == att.id, do: "bg-info text-white shadow-md", else: "hover:bg-base-200"}"}
                    >
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class="bg-neutral text-neutral-content rounded-full w-10">
                            <span class="text-sm font-bold">
                              <%= String.first(att.user.username || att.user.email) |> String.upcase() %>
                            </span>
                          </div>
                        </div>
                        <div class="flex-1">
                          <p class="font-medium"><%= att.user.username || att.user.email %></p>
                          <p class="text-xs opacity-70"><%= att.department.name %></p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Attachee Tasks + Evaluate -->
            <div class="card bg-base-100 shadow-xl" :if={@selected_attachee}>
              <div class="card-body">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="card-title"><%= @selected_attachee.user.username %>'s Tasks</h2>
                  <.button phx-click="toggle_evaluation_form" size="sm" class="btn-outline">
                    Evaluate
                  </.button>
                </div>

                <div :if={@attachee_tasks == []} class="text-center py-8">
                  <p class="text-base-content/50">No tasks assigned</p>
                  <.button
                    phx-click="toggle_task_form"
                    size="sm"
                    class="mt-4 btn-sm"
                    :if={@selected_project}
                  >
                    Assign Task
                  </.button>
                </div>

                <div class="space-y-3" :if={@attachee_tasks != []}>
                  <%= for task <- @attachee_tasks do %>
                    <div class="p-3 bg-base-200 rounded-lg">
                      <p class="font-medium"><%= task.title %></p>
                      <p class="text-sm opacity-70 mt-1"><%= task.description || "No description" %></p>
                      <div class="flex items-center gap-2 mt-2">
                        <span class={"badge badge-sm #{status_color(task.status)}"}>
                          <%= String.capitalize(task.status) %>
                        </span>
                        <%= if task.due_date do %>
                          <span class="text-xs opacity-60">
                            Due: <%= Calendar.strftime(task.due_date, "%b %d") %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Empty State -->
            <div :if={!@selected_project && !@selected_attachee} class="lg:col-span-2">
              <div class="card bg-base-100 shadow-xl h-full">
                <div class="card-body flex items-center justify-center text-center">
                  <div>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-20 w-20 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                    <h3 class="text-xl font-bold mt-4">Select a Project</h3>
                    <p class="text-base-content/70 mt-2">Choose a project to view attachees and assign tasks.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Recent Activities -->
          <div class="mt-8 card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Recent Activities</h2>
              <div :if={@recent_activities == []} class="text-center py-8">
                <p class="text-base-content/50">No recent activities</p>
              </div>
              <div class="space-y-3" :if={@recent_activities != []}>
                <%= for activity <- @recent_activities do %>
                  <div class="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                    <div>
                      <p class="font-medium"><%= activity.attachee_name %></p>
                      <p class="text-sm opacity-70"><%= activity.description %></p>
                    </div>
                    <div class="text-right">
                      <p class="text-xs opacity-60"><%= activity.time %></p>
                      <span class={"badge badge-sm #{status_color(activity.status)}"}>
                        <%= String.capitalize(activity.status) %>
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Modals -->
      <.live_component
        :if={@show_project_form}
        module={ProjectForm}
        id="project-form"
        current_user={@current_user}
        programs={@programs}
      />

      <.live_component
        :if={@show_task_form}
        module={TaskForm}
        id="task-form"
        project={@selected_project}
        attachees={@attachees}
      />

      <.live_component
        :if={@show_evaluation_form}
        module={EvaluationForm}
        id="eval-form"
        attachee={@selected_attachee}
        current_user={@current_user}
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
  defp status_color("overdue"), do: "badge-error"
  defp status_color(_), do: "badge-ghost"
end
