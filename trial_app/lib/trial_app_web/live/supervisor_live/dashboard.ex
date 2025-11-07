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
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)
     |> assign(:show_evaluation_form, false)
     |> load_data(current_user)}
  end

  defp load_data(socket, user) do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)
    programs = Eams.list_programs_by_department(dept.id)

    # Fixed: Handle empty programs list safely
    projects = case programs do
      [] -> []
      [first_program | _] -> Eams.list_projects_by_program(first_program.id)
    end

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:programs, programs)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats(user))
    |> assign(:recent_activities, load_recent_activities(user))
  end

  @impl true
  def handle_event("select_project", %{"id" => id}, socket) do
    # Fixed: Pass map instead of keyword list
    project = Eams.get_project!(id, %{preloads: [:program]})
    attachees = Eams.list_attachees_in_project(id) || []

    {:noreply,
     socket
     |> assign(:selected_project, project)
     |> assign(:attachees, attachees)
     |> assign(:selected_attachee, nil)}
  end

  def handle_event("select_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id, %{preloads: [:user]})
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
     |> assign(:show_project_form, false)
     |> assign(:show_task_form, false)
     |> assign(:show_evaluation_form, false)}
  end

  def handle_info({:project_created, project}, socket) do
    {:noreply, assign(socket, :projects, [project | socket.assigns.projects])}
  end

  def handle_info({:task_created, _}, socket) do
    {:noreply, socket}
  end

  def handle_info({:evaluation_submitted, _}, socket) do
    {:noreply, put_flash(socket, :info, "Evaluation submitted!")}
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
              <.button phx-click="toggle_project_form">+ New Project</.button>
              <.button phx-click="toggle_task_form" :if={@selected_project}>+ Assign Task</.button>
            </div>
          </div>

          <!-- Stats Cards -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <!-- Total Attachees -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Total Attachees</p>
                <p class="text-3xl font-bold"><%= @stats.total_attachees %></p>
              </div>
            </div>
            <!-- Active Tasks -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Active Tasks</p>
                <p class="text-3xl font-bold"><%= @stats.active_tasks %></p>
              </div>
            </div>
            <!-- Pending Reviews -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Pending Reviews</p>
                <p class="text-3xl font-bold"><%= @stats.pending_reviews %></p>
              </div>
            </div>
            <!-- Completed This Week -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Completed</p>
                <p class="text-3xl font-bold"><%= @stats.completed_this_week %></p>
              </div>
            </div>
          </div>

          <!-- Projects & Attachees -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Projects List -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Projects</h2>

                <!-- Empty State -->
                <div :if={@projects == []} class="text-center py-8">
                  <p class="text-base-content/50">No projects yet</p>
                  <.button phx-click="toggle_project_form" class="mt-4">Create First Project</.button>
                </div>

                <!-- Projects List -->
                <div class="space-y-2" :if={@projects != []}>
                  <%= for project <- @projects do %>
                    <div
                      phx-click="select_project"
                      phx-value-id={project.id}
                      class={"p-3 rounded-lg cursor-pointer #{if @selected_project && @selected_project.id == project.id, do: "bg-primary text-white", else: "hover:bg-base-200"}"}
                    >
                      <p class="font-medium"><%= project.name %></p>
                      <p class="text-sm opacity-70"><%= project.program.name %></p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Attachees in Project -->
            <div class="card bg-base-100 shadow-xl" :if={@selected_project}>
              <div class="card-body">
                <h2 class="card-title">Attachees in <%= @selected_project.name %></h2>

                <!-- Empty State -->
                <div :if={@attachees == []} class="text-center py-8">
                  <p class="text-base-content/50">No attachees assigned yet</p>
                </div>

                <!-- Attachees List -->
                <div class="space-y-2" :if={@attachees != []}>
                  <%= for att <- @attachees do %>
                    <div
                      phx-click="select_attachee"
                      phx-value-id={att.id}
                      class={"p-3 rounded-lg cursor-pointer #{if @selected_attachee && @selected_attachee.id == att.id, do: "bg-info text-white", else: "hover:bg-base-200"}"}
                    >
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class="bg-neutral text-neutral-content rounded-full w-8">
                            <span class="text-xs"><%= String.first(att.user.username || att.user.email) %></span>
                          </div>
                        </div>
                        <div>
                          <p class="font-medium"><%= att.user.username || att.user.email %></p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Attachee Tasks + Eval -->
            <div class="card bg-base-100 shadow-xl" :if={@selected_attachee}>
              <div class="card-body">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="card-title"><%= @selected_attachee.user.username %>'s Tasks</h2>
                  <.button phx-click="toggle_evaluation_form" size="sm">Evaluate</.button>
                </div>

                <!-- Empty State -->
                <div :if={@attachee_tasks == []} class="text-center py-8">
                  <p class="text-base-content/50">No tasks assigned yet</p>
                  <.button phx-click="toggle_task_form" size="sm" class="mt-4">Assign Task</.button>
                </div>

                <!-- Tasks List -->
                <div class="space-y-3" :if={@attachee_tasks != []}>
                  <%= for task <- @attachee_tasks do %>
                    <div class="p-3 bg-base-200 rounded-lg">
                      <p class="font-medium"><%= task.title %></p>
                      <div class="flex items-center gap-2 mt-1">
                        <span class={"badge badge-sm #{status_color(task.status)}"}><%= task.status %></span>
                      </div>
                    </div>
                  <% end %>
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
              <!-- Add your table/list here when you have activities -->
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

  # Helper function for task status colors
  defp status_color("pending"), do: "badge-warning"
  defp status_color("in_progress"), do: "badge-info"
  defp status_color("completed"), do: "badge-success"
  defp status_color("overdue"), do: "badge-error"
  defp status_color(_), do: "badge-ghost"
end
