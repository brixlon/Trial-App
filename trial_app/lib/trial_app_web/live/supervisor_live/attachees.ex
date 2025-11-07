defmodule TrialAppWeb.SupervisorLive.Attachees do
  use TrialAppWeb, :live_view
  import Ecto.Query
  alias TrialApp.{Eams, Orgs, Repo}
  alias TrialAppWeb.SupervisorLive.EvaluationForm

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Manage Attachees")
     |> assign(:current_user, current_user)
     |> assign(:selected_attachee, nil)
     |> assign(:show_evaluation_form, false)
     |> load_supervisor_data(current_user)}
  end

  defp load_supervisor_data(socket, user) do
    # Get all projects supervised by this user
    projects = from(p in Eams.Project,
      where: p.supervisor_id == ^user.id,
      preload: [:program]
    )
    |> Repo.all()

    # Get all attachees from these projects
    attachees = if projects != [] do
      project_ids = Enum.map(projects, & &1.id)
      load_attachees_from_projects(project_ids)
    else
      []
    end

    # Get programs from projects
    programs = projects
    |> Enum.map(& &1.program)
    |> Enum.uniq_by(& &1.id)

    socket
    |> assign(:projects, projects)
    |> assign(:programs, programs)
    |> assign(:attachees, attachees)
    |> assign(:total_attachees, length(attachees))
  end

  defp load_attachees_from_projects(project_ids) do
    from(a in Eams.Attachee,
      join: ap in Eams.AttacheeProgram, on: ap.attachee_id == a.id,
      join: proj in Eams.Project, on: ap.project_id == proj.id,
      where: proj.id in ^project_ids,
      distinct: a.id,
      preload: [:user, :department, :organization, :position]
    )
    |> Repo.all()
  end

  @impl true
  def handle_event("select_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id, %{preloads: [:user, :department, :organization, :position]})

    # Get attachee's tasks (only from supervisor's projects)
    supervisor_project_ids = Enum.map(socket.assigns.projects, & &1.id)
    tasks = load_attachee_tasks(attachee.id, supervisor_project_ids)

    # Get attachee's projects (only supervisor's projects)
    projects = Enum.filter(socket.assigns.projects, fn proj ->
      # Check if attachee is assigned to this project
      from(ap in Eams.AttacheeProgram,
        where: ap.attachee_id == ^attachee.id,
        where: ap.project_id == ^proj.id
      )
      |> Repo.exists?()
    end)

    # Get attachee's programs
    programs = projects
    |> Enum.map(& &1.program)
    |> Enum.uniq_by(& &1.id)

    # Get evaluations history (if Evaluation schema exists)
    evaluations = try do
      from(e in Eams.Evaluation,
        where: e.attachee_id == ^attachee.id,
        order_by: [desc: e.inserted_at],
        preload: [:evaluator]
      )
      |> Repo.all()
    rescue
      _ -> []
    end

    # Calculate comprehensive stats
    stats = calculate_comprehensive_stats(tasks, evaluations)

    # Get task history with timeline
    task_history = load_task_history(tasks)

    {:noreply,
     socket
     |> assign(:selected_attachee, attachee)
     |> assign(:attachee_tasks, tasks)
     |> assign(:attachee_projects, projects)
     |> assign(:attachee_programs, programs)
     |> assign(:attachee_evaluations, evaluations)
     |> assign(:attachee_stats, stats)
     |> assign(:task_history, task_history)}
  end

  def handle_event("close_profile", _, socket) do
    {:noreply, assign(socket, :selected_attachee, nil)}
  end

  def handle_event("toggle_evaluation_form", _, socket) do
    {:noreply, assign(socket, :show_evaluation_form, !socket.assigns.show_evaluation_form)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_evaluation_form, false)}
  end

  @impl true
  def handle_info({:evaluation_submitted, _}, socket) do
    # Reload data after evaluation
    current_user = socket.assigns.current_user

    {:noreply,
     socket
     |> put_flash(:info, "Evaluation submitted successfully!")
     |> assign(:show_evaluation_form, false)
     |> load_supervisor_data(current_user)}
  end

  defp load_attachee_tasks(attachee_id, project_ids) do
    from(t in Eams.Task,
      where: t.assignee_id == ^attachee_id,
      where: t.project_id in ^project_ids,
      order_by: [desc: t.inserted_at],
      preload: [:project, :assignee]
    )
    |> Repo.all()
  end

  defp load_task_history(tasks) do
    tasks
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.map(fn task ->
      %{
        task: task,
        status_changes: get_status_changes(task),
        time_taken: calculate_time_taken(task)
      }
    end)
  end

  defp get_status_changes(task) do
    # You can implement this to track status changes from activity logs
    # For now, returning basic info
    [
      %{status: task.status, timestamp: task.updated_at || task.inserted_at}
    ]
  end

  defp calculate_time_taken(task) do
    if task.status == "completed" && task.submitted_at do
      days = DateTime.diff(task.submitted_at, task.inserted_at, :day)
      "#{days} days"
    else
      if task.due_date do
        today = Date.utc_today()
        days_remaining = Date.diff(task.due_date, today)
        if days_remaining < 0 do
          "#{abs(days_remaining)} days overdue"
        else
          "#{days_remaining} days remaining"
        end
      else
        "No due date"
      end
    end
  end

  defp calculate_comprehensive_stats(tasks, evaluations) do
    total = length(tasks)
    completed = Enum.count(tasks, &(&1.status == "completed"))
    pending = Enum.count(tasks, &(&1.status in ["pending"]))
    in_progress = Enum.count(tasks, &(&1.status == "in_progress"))
    submitted = Enum.count(tasks, &(&1.status == "submitted"))
    rejected = Enum.count(tasks, &(&1.status == "rejected"))

    completion_rate = if total > 0, do: Float.round(completed / total * 100, 1), else: 0

    # Calculate average score from evaluations
    avg_score = if evaluations != [] do
      total_score = Enum.reduce(evaluations, 0, fn eval, acc ->
        acc + (eval.score || 0)
      end)
      Float.round(total_score / length(evaluations), 1)
    else
      0
    end

    # On-time completion rate
    completed_tasks = Enum.filter(tasks, &(&1.status == "completed"))
    on_time_count = Enum.count(completed_tasks, fn task ->
      task.completed_at && task.due_date &&
      Date.compare(DateTime.to_date(task.completed_at), task.due_date) != :gt
    end)

    on_time_rate = if length(completed_tasks) > 0 do
      Float.round(on_time_count / length(completed_tasks) * 100, 1)
    else
      0
    end

    %{
      total_tasks: total,
      completed: completed,
      pending: pending,
      in_progress: in_progress,
      submitted: submitted,
      rejected: rejected,
      completion_rate: completion_rate,
      avg_score: avg_score,
      on_time_rate: on_time_rate,
      total_evaluations: length(evaluations)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="lg:ml-64 p-8">
        <div class="max-w-7xl mx-auto">
          <!-- Header -->
          <div class="mb-8">
            <h1 class="text-3xl font-bold">Manage Attachees</h1>
            <p class="text-base-content/70">View and evaluate attachees in your supervised projects</p>
          </div>

          <!-- Stats Overview -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Total Attachees</p>
                <p class="text-3xl font-bold"><%= @total_attachees %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Projects</p>
                <p class="text-3xl font-bold text-primary"><%= length(@projects) %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Programs</p>
                <p class="text-3xl font-bold text-secondary"><%= length(@programs) %></p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Active</p>
                <p class="text-3xl font-bold text-success">
                  <%= Enum.count(@attachees, fn a -> a.user.status == "active" end) %>
                </p>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Attachees List -->
            <div class="lg:col-span-1 card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">Attachees in Your Projects</h2>

                <!-- Empty State -->
                <div :if={@attachees == []} class="text-center py-8">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                  <p class="text-base-content/50 mt-4">No attachees in your projects yet</p>
                </div>

                <!-- Attachees List -->
                <div class="space-y-2 max-h-[600px] overflow-y-auto" :if={@attachees != []}>
                  <%= for attachee <- @attachees do %>
                    <div
                      phx-click="select_attachee"
                      phx-value-id={attachee.id}
                      class={"p-4 rounded-lg cursor-pointer transition-all #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "bg-primary text-white shadow-lg", else: "hover:bg-base-200 hover:shadow"}"}
                    >
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class={"rounded-full w-12 #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "bg-primary-content text-primary", else: "bg-neutral text-neutral-content"}"}>
                            <span class="text-lg font-bold">
                              <%= String.first(attachee.user.username || attachee.user.email) |> String.upcase() %>
                            </span>
                          </div>
                        </div>
                        <div class="flex-1 min-w-0">
                          <p class="font-medium truncate"><%= attachee.user.username || attachee.user.email %></p>
                          <p class={"text-sm truncate #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "opacity-90", else: "opacity-70"}"}>
                            <%= attachee.department.name %>
                          </p>
                          <p class={"text-xs truncate #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "opacity-80", else: "opacity-60"}"}>
                            <%= if attachee.position, do: attachee.position.title, else: "No position" %>
                          </p>
                        </div>
                        <div class={"badge badge-sm #{status_badge(attachee.user.status)}"}>
                          <%= attachee.user.status %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Attachee Profile & Details -->
            <div :if={@selected_attachee} class="lg:col-span-2 space-y-6">
              <!-- Profile Card -->
              <div class="card bg-gradient-to-br from-primary/10 to-secondary/10 shadow-xl">
                <div class="card-body">
                  <div class="flex justify-between items-start mb-4">
                    <div class="flex items-center gap-4">
                      <div class="avatar placeholder">
                        <div class="bg-primary text-primary-content rounded-full w-20 ring ring-primary ring-offset-base-100 ring-offset-2">
                          <span class="text-3xl font-bold">
                            <%= String.first(@selected_attachee.user.username || @selected_attachee.user.email) |> String.upcase() %>
                          </span>
                        </div>
                      </div>
                      <div>
                        <h2 class="text-2xl font-bold"><%= @selected_attachee.user.username || "Unnamed User" %></h2>
                        <p class="text-base-content/70"><%= @selected_attachee.user.email %></p>
                        <div class="flex gap-2 mt-2">
                          <span class={"badge #{status_badge(@selected_attachee.user.status)}"}>
                            <%= @selected_attachee.user.status %>
                          </span>
                          <span class="badge badge-outline">
                            Attachee ID: <%= @selected_attachee.id %>
                          </span>
                        </div>
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <button phx-click="toggle_evaluation_form" class="btn btn-primary btn-sm gap-2">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                        </svg>
                        Evaluate
                      </button>
                      <button phx-click="close_profile" class="btn btn-ghost btn-sm">
                        Close
                      </button>
                    </div>
                  </div>

                  <!-- Info Grid -->
                  <div class="grid grid-cols-2 md:grid-cols-3 gap-4 mt-4">
                    <div class="bg-base-100 p-3 rounded-lg">
                      <p class="text-xs text-base-content/70 mb-1">Organization</p>
                      <p class="font-medium"><%= @selected_attachee.organization.name %></p>
                    </div>
                    <div class="bg-base-100 p-3 rounded-lg">
                      <p class="text-xs text-base-content/70 mb-1">Department</p>
                      <p class="font-medium"><%= @selected_attachee.department.name %></p>
                    </div>
                    <div class="bg-base-100 p-3 rounded-lg">
                      <p class="text-xs text-base-content/70 mb-1">Position</p>
                      <p class="font-medium"><%= if @selected_attachee.position, do: @selected_attachee.position.title, else: "Not assigned" %></p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Performance Stats -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                    </svg>
                    Performance Overview
                  </h3>
                  <div class="grid grid-cols-2 md:grid-cols-5 gap-4 mt-4">
                    <div class="stat bg-base-200 rounded-lg p-4">
                      <div class="stat-title text-xs">Total Tasks</div>
                      <div class="stat-value text-2xl"><%= @attachee_stats.total_tasks %></div>
                    </div>
                    <div class="stat bg-success/10 rounded-lg p-4">
                      <div class="stat-title text-xs text-success">Completed</div>
                      <div class="stat-value text-2xl text-success"><%= @attachee_stats.completed %></div>
                    </div>
                    <div class="stat bg-info/10 rounded-lg p-4">
                      <div class="stat-title text-xs text-info">In Progress</div>
                      <div class="stat-value text-2xl text-info"><%= @attachee_stats.in_progress %></div>
                    </div>
                    <div class="stat bg-warning/10 rounded-lg p-4">
                      <div class="stat-title text-xs text-warning">Pending</div>
                      <div class="stat-value text-2xl text-warning"><%= @attachee_stats.pending %></div>
                    </div>
                    <div class="stat bg-error/10 rounded-lg p-4">
                      <div class="stat-title text-xs text-error">Rejected</div>
                      <div class="stat-value text-2xl text-error"><%= @attachee_stats.rejected %></div>
                    </div>
                  </div>

                  <!-- Progress Bars -->
                  <div class="mt-6 space-y-4">
                    <div>
                      <div class="flex justify-between mb-2">
                        <span class="text-sm font-medium">Completion Rate</span>
                        <span class="text-sm font-bold text-success"><%= @attachee_stats.completion_rate %>%</span>
                      </div>
                      <progress
                        class="progress progress-success w-full h-3"
                        value={@attachee_stats.completion_rate}
                        max="100"
                      ></progress>
                    </div>

                    <div>
                      <div class="flex justify-between mb-2">
                        <span class="text-sm font-medium">On-Time Delivery</span>
                        <span class="text-sm font-bold text-info"><%= @attachee_stats.on_time_rate %>%</span>
                      </div>
                      <progress
                        class="progress progress-info w-full h-3"
                        value={@attachee_stats.on_time_rate}
                        max="100"
                      ></progress>
                    </div>

                    <div>
                      <div class="flex justify-between mb-2">
                        <span class="text-sm font-medium">Average Evaluation Score</span>
                        <span class="text-sm font-bold text-warning"><%= @attachee_stats.avg_score %>/10</span>
                      </div>
                      <progress
                        class="progress progress-warning w-full h-3"
                        value={@attachee_stats.avg_score * 10}
                        max="100"
                      ></progress>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Programs & Projects -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <!-- Programs -->
                <div class="card bg-base-100 shadow-xl">
                  <div class="card-body">
                    <h3 class="card-title text-lg">Enrolled Programs</h3>
                    <div :if={@attachee_programs == []} class="text-center py-4">
                      <p class="text-base-content/50 text-sm">No programs enrolled</p>
                    </div>
                    <div class="space-y-2" :if={@attachee_programs != []}>
                      <%= for program <- @attachee_programs do %>
                        <div class="p-3 bg-primary/10 rounded-lg border border-primary/20">
                          <p class="font-medium"><%= program.name %></p>
                          <p class="text-sm opacity-70"><%= program.code %></p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <!-- Projects -->
                <div class="card bg-base-100 shadow-xl">
                  <div class="card-body">
                    <h3 class="card-title text-lg">Assigned Projects</h3>
                    <div :if={@attachee_projects == []} class="text-center py-4">
                      <p class="text-base-content/50 text-sm">No projects assigned</p>
                    </div>
                    <div class="space-y-2" :if={@attachee_projects != []}>
                      <%= for project <- @attachee_projects do %>
                        <div class="p-3 bg-secondary/10 rounded-lg border border-secondary/20">
                          <p class="font-medium"><%= project.name %></p>
                          <p class="text-sm opacity-70"><%= project.program.name %></p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Current Tasks -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                    </svg>
                    All Tasks
                  </h3>
                  <div :if={@attachee_tasks == []} class="text-center py-8">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                    <p class="text-base-content/50 mt-2">No tasks assigned yet</p>
                  </div>
                  <div class="overflow-x-auto" :if={@attachee_tasks != []}>
                    <table class="table table-zebra">
                      <thead>
                        <tr>
                          <th>Task</th>
                          <th>Project</th>
                          <th>Status</th>
                          <th>Due Date</th>
                          <th>Time Info</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for item <- @task_history do %>
                          <tr class="hover">
                            <td>
                              <div>
                                <div class="font-medium"><%= item.task.title %></div>
                                <div class="text-sm opacity-70 max-w-xs truncate"><%= item.task.description || "No description" %></div>
                              </div>
                            </td>
                            <td><%= item.task.project.name %></td>
                            <td>
                              <span class={"badge badge-sm #{task_status_badge(item.task.status)}"}>
                                <%= item.task.status %>
                              </span>
                            </td>
                            <td>
                              <%= if item.task.due_date do %>
                                <%= Calendar.strftime(item.task.due_date, "%b %d, %Y") %>
                              <% else %>
                                <span class="text-base-content/50">No due date</span>
                              <% end %>
                            </td>
                            <td>
                              <span class="text-sm"><%= item.time_taken %></span>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              <!-- Evaluation History -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                    </svg>
                    Evaluation History
                    <span class="badge badge-primary badge-sm"><%= @attachee_stats.total_evaluations %></span>
                  </h3>
                  <div :if={@attachee_evaluations == []} class="text-center py-8">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <p class="text-base-content/50 mt-2">No evaluations yet</p>
                    <button phx-click="toggle_evaluation_form" class="btn btn-primary btn-sm mt-4">
                      Create First Evaluation
                    </button>
                  </div>
                  <div class="space-y-3" :if={@attachee_evaluations != []}>
                    <%= for eval <- Enum.take(@attachee_evaluations, 5) do %>
                      <div class="p-4 bg-base-200 rounded-lg">
                        <div class="flex justify-between items-start mb-2">
                          <div>
                            <p class="font-medium">Evaluation by <%= eval.evaluator.username || eval.evaluator.email %></p>
                            <p class="text-sm opacity-70">
                              <%= if eval.inserted_at do %>
                                <%= Timex.format!(eval.inserted_at, "{relative}", :relative) %>
                              <% else %>
                                Recently submitted
                              <% end %>
                            </p>
                          </div>
                          <div class="text-right">
                            <div class="flex items-center gap-1">
                              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-warning" viewBox="0 0 20 20" fill="currentColor">
                                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                              </svg>
                              <span class="text-lg font-bold"><%= eval.score %>/10</span>
                            </div>
                          </div>
                        </div>
                        <p class="text-sm mt-2"><%= eval.comments || "No comments provided" %></p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Activity Timeline -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Recent Activity Timeline
                  </h3>
                  <div class="space-y-3 mt-4">
                    <%= for item <- Enum.take(@task_history, 10) do %>
                      <div class="flex items-start gap-3">
                        <div class={"w-3 h-3 rounded-full mt-1.5 flex-shrink-0 #{activity_indicator(item.task.status)}"}></div>
                        <div class="flex-1 pb-4 border-l-2 border-base-300 pl-4 ml-1.5">
                          <p class="font-medium"><%= item.task.title %></p>
                          <p class="text-sm opacity-70"><%= item.task.project.name %></p>
                          <div class="flex items-center gap-2 mt-2">
                            <span class={"badge badge-sm #{task_status_badge(item.task.status)}"}>
                              <%= item.task.status %>
                            </span>
                            <span class="text-xs opacity-60">
                              <%= if item.task.updated_at do %>
                                <%= Timex.format!(item.task.updated_at, "{relative}", :relative) %>
                              <% else %>
                                Recently created
                              <% end %>
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <!-- Empty State When No Attachee Selected -->
            <div :if={!@selected_attachee} class="lg:col-span-2">
              <div class="card bg-base-100 shadow-xl h-full">
                <div class="card-body flex items-center justify-center">
                  <div class="text-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-32 w-32 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    <h3 class="text-2xl font-bold mt-6">Select an Attachee</h3>
                    <p class="text-base-content/70 mt-2 max-w-md">Choose an attachee from the list to view their complete profile, performance metrics, task history, and evaluation records</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Evaluation Modal -->
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

  # Helper functions for styling
  defp status_badge("active"), do: "badge-success"
  defp status_badge("inactive"), do: "badge-error"
  defp status_badge(_), do: "badge-ghost"

  defp task_status_badge("completed"), do: "badge-success"
  defp task_status_badge("in_progress"), do: "badge-info"
  defp task_status_badge("pending"), do: "badge-warning"
  defp task_status_badge("submitted"), do: "badge-primary"
  defp task_status_badge("rejected"), do: "badge-error"
  defp task_status_badge(_), do: "badge-ghost"

  defp activity_indicator("completed"), do: "bg-success"
  defp activity_indicator("in_progress"), do: "bg-info"
  defp activity_indicator("pending"), do: "bg-warning"
  defp activity_indicator("submitted"), do: "bg-primary"
  defp activity_indicator("rejected"), do: "bg-error"
  defp activity_indicator(_), do: "bg-base-content/20"
end
