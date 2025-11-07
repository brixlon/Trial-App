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
     |> assign(:evaluations, [])
     |> assign(:avg_score, 0)
     |> assign(:eval_count, 0)
     |> load_attachees(current_user)}
  end

  defp load_attachees(socket, user) do
    # Get attachees only in projects supervised by this user
    attachee_list = load_attachee_list(user.id)

    # Count total
    total_attachees = length(attachee_list)

    # Debug info
    IO.inspect(user.id, label: "Supervisor ID")
    IO.inspect(total_attachees, label: "Total Attachees Found")

    socket
    |> assign(:total_attachees, total_attachees)
    |> assign(:attachees, attachee_list)
  end

  defp load_attachee_list(supervisor_id) do
    # Check if projects have supervisor_id column
    # First try: Get attachees through projects with supervisor_id
    query1 = from(a in Eams.Attachee,
      join: t in Eams.Task, on: t.assignee_id == a.id,
      join: p in Eams.Project, on: t.project_id == p.id,
      where: p.supervisor_id == ^supervisor_id,
      distinct: a.id,
      preload: [:user, :department, :organization]
    )

    result = Repo.all(query1)
    IO.inspect(result, label: "Attachees via Projects with supervisor_id")

    # If empty, try alternative: Get all attachees with tasks in any project
    # This is for debugging - remove once we know the right approach
    if result == [] do
      IO.puts("No attachees found via supervisor_id, trying alternative query...")

      # Alternative: Get attachees by department (if supervisor manages department)
      dept_result = from(a in Eams.Attachee,
        where: a.department_id == ^get_supervisor_department_id(supervisor_id),
        preload: [:user, :department, :organization]
      )
      |> Repo.all()

      IO.inspect(dept_result, label: "Attachees via Department")
      dept_result
    else
      result
    end
  end

  defp get_supervisor_department_id(supervisor_id) do
    # Get the department where this supervisor works
    case Orgs.get_department_for_user(supervisor_id) do
      nil -> nil
      dept -> dept.id
    end
  end

  @impl true
  def handle_event("select_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id, %{preloads: [:user, :department, :organization]})

    # Get attachee's tasks
    tasks = Eams.list_tasks_for_attachee(attachee.id)

    # Get attachee's projects
    projects = Eams.list_projects_for_attachee(attachee.id)

    # Get attachee's programs
    programs = Eams.list_programs_for_attachee(attachee.id)

    # Get evaluations
    evaluations = Eams.list_evaluations_for_attachee(attachee.id, %{preloads: [:evaluator]})
    avg_score = Eams.get_average_evaluation_score(attachee.id)
    eval_count = Eams.count_evaluations_for_attachee(attachee.id)

    # Calculate stats
    stats = calculate_attachee_stats(attachee)

    {:noreply,
     socket
     |> assign(:selected_attachee, attachee)
     |> assign(:attachee_tasks, tasks)
     |> assign(:attachee_projects, projects)
     |> assign(:attachee_programs, programs)
     |> assign(:attachee_stats, stats)
     |> assign(:evaluations, evaluations)
     |> assign(:avg_score, avg_score)
     |> assign(:eval_count, eval_count)}
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
  def handle_info({:evaluation_submitted, attachee_id}, socket) do
    # Reload the attachee to get fresh data
    attachee = Eams.get_attachee!(attachee_id, %{preloads: [:user, :department, :organization]})

    # Reload evaluations
    evaluations = Eams.list_evaluations_for_attachee(attachee_id, %{preloads: [:evaluator]})
    avg_score = Eams.get_average_evaluation_score(attachee_id)
    eval_count = Eams.count_evaluations_for_attachee(attachee_id)

    {:noreply,
     socket
     |> put_flash(:info, "Evaluation submitted successfully!")
     |> assign(:show_evaluation_form, false)
     |> assign(:selected_attachee, attachee)
     |> assign(:evaluations, evaluations)
     |> assign(:avg_score, avg_score)
     |> assign(:eval_count, eval_count)}
  end

  def handle_info({:close_modal, _}, socket) do
    {:noreply, assign(socket, :show_evaluation_form, false)}
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
            <p class="text-base-content/70">View and evaluate attachees under your supervision</p>
          </div>

          <!-- Stats Overview -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Total Attachees</p>
                <p class="text-3xl font-bold"><%= @total_attachees %></p>
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
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Selected</p>
                <p class="text-3xl font-bold text-info">
                  <%= if @selected_attachee, do: "1", else: "0" %>
                </p>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Attachees List -->
            <div class="lg:col-span-1 card bg-base-100 shadow-xl">
              <div class="card-body">
                <h2 class="card-title">All Attachees</h2>

                <!-- Empty State -->
                <div :if={@attachees == []} class="text-center py-8">
                  <p class="text-base-content/50">No attachees found</p>
                </div>

                <!-- Attachees List -->
                <div class="space-y-2 max-h-[600px] overflow-y-auto" :if={@attachees != []}>
                  <%= for attachee <- @attachees do %>
                    <div
                      phx-click="select_attachee"
                      phx-value-id={attachee.id}
                      class={"p-4 rounded-lg cursor-pointer transition-all #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "bg-primary text-white", else: "hover:bg-base-200"}"}
                    >
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class={"rounded-full w-12 #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "bg-primary-content text-primary", else: "bg-neutral text-neutral-content"}"}>
                            <span class="text-lg">
                              <%= String.first(attachee.user.username || attachee.user.email) |> String.upcase() %>
                            </span>
                          </div>
                        </div>
                        <div class="flex-1">
                          <p class="font-medium"><%= attachee.user.username || attachee.user.email %></p>
                          <p class={"text-sm #{if @selected_attachee && @selected_attachee.id == attachee.id, do: "opacity-90", else: "opacity-70"}"}>
                            <%= attachee.department.name %>
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
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <div class="flex justify-between items-start mb-4">
                    <div class="flex items-center gap-4">
                      <div class="avatar placeholder">
                        <div class="bg-primary text-primary-content rounded-full w-16">
                          <span class="text-2xl">
                            <%= String.first(@selected_attachee.user.username || @selected_attachee.user.email) |> String.upcase() %>
                          </span>
                        </div>
                      </div>
                      <div>
                        <h2 class="text-2xl font-bold"><%= @selected_attachee.user.username || @selected_attachee.user.email %></h2>
                        <p class="text-base-content/70"><%= @selected_attachee.user.email %></p>
                        <div class="flex gap-2 mt-2">
                          <span class={"badge #{status_badge(@selected_attachee.user.status)}"}>
                            <%= @selected_attachee.user.status %>
                          </span>
                        </div>
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <button phx-click="toggle_evaluation_form" class="btn btn-primary btn-sm">
                        Evaluate
                      </button>
                      <button phx-click="close_profile" class="btn btn-ghost btn-sm">
                        Close
                      </button>
                    </div>
                  </div>

                  <!-- Info Grid -->
                  <div class="grid grid-cols-2 gap-4 mt-4">
                    <div>
                      <p class="text-sm text-base-content/70">Department</p>
                      <p class="font-medium"><%= @selected_attachee.department.name %></p>
                    </div>
                    <div>
                      <p class="text-sm text-base-content/70">Organization</p>
                      <p class="font-medium"><%= @selected_attachee.organization.name %></p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Performance Stats -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title">Performance Overview</h3>
                  <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
                    <div class="stat bg-base-200 rounded-lg">
                      <div class="stat-title">Total Tasks</div>
                      <div class="stat-value text-2xl"><%= @attachee_stats.total_tasks %></div>
                    </div>
                    <div class="stat bg-success/10 rounded-lg">
                      <div class="stat-title text-success">Completed</div>
                      <div class="stat-value text-2xl text-success"><%= @attachee_stats.completed %></div>
                    </div>
                    <div class="stat bg-warning/10 rounded-lg">
                      <div class="stat-title text-warning">Pending</div>
                      <div class="stat-value text-2xl text-warning"><%= @attachee_stats.pending %></div>
                    </div>
                    <div class="stat bg-info/10 rounded-lg">
                      <div class="stat-title text-info">Submitted</div>
                      <div class="stat-value text-2xl text-info"><%= @attachee_stats.submitted %></div>
                    </div>
                  </div>

                  <!-- Completion Rate -->
                  <div class="mt-4">
                    <div class="flex justify-between mb-2">
                      <span class="text-sm font-medium">Completion Rate</span>
                      <span class="text-sm font-bold"><%= @attachee_stats.completion_rate %>%</span>
                    </div>
                    <progress
                      class="progress progress-success w-full"
                      value={@attachee_stats.completion_rate}
                      max="100"
                    ></progress>
                  </div>
                </div>
              </div>

              <!-- Evaluation History -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <div class="flex justify-between items-center mb-4">
                    <h3 class="card-title">Evaluation History</h3>
                    <div class="flex items-center gap-4">
                      <div class="text-center">
                        <div class="stat-value text-2xl text-primary"><%= @avg_score %></div>
                        <div class="stat-desc">Average Score</div>
                      </div>
                      <div class="text-center">
                        <div class="stat-value text-2xl"><%= @eval_count %></div>
                        <div class="stat-desc">Total Evaluations</div>
                      </div>
                    </div>
                  </div>

                  <div :if={@evaluations == []} class="text-center py-8">
                    <p class="text-base-content/50">No evaluations yet</p>
                    <p class="text-sm text-base-content/40 mt-1">Click "Evaluate" to submit the first evaluation</p>
                  </div>

                  <div :if={@evaluations != []} class="space-y-4 max-h-96 overflow-y-auto">
                    <%= for evaluation <- @evaluations do %>
                      <div class="border border-base-300 rounded-lg p-4 hover:bg-base-200 transition">
                        <div class="flex justify-between items-start mb-3">
                          <div class="flex items-center gap-3">
                            <div class={"avatar placeholder #{score_color_class(evaluation.score)}"}>
                              <div class="w-12 rounded-full">
                                <span class="text-xl font-bold"><%= evaluation.score %></span>
                              </div>
                            </div>
                            <div>
                              <p class="font-semibold">
                                Score: <%= evaluation.score %>/100
                              </p>
                              <p class="text-sm text-base-content/70">
                                by <%= evaluation.evaluator.username || evaluation.evaluator.email %>
                              </p>
                            </div>
                          </div>
                          <div class="text-right">
                            <p class="text-sm text-base-content/70">
                              <%= Calendar.strftime(evaluation.inserted_at, "%b %d, %Y") %>
                            </p>
                            <p class="text-xs text-base-content/50">
                              <%= Timex.from_now(evaluation.inserted_at) %>
                            </p>
                          </div>
                        </div>

                        <div class="bg-base-100 p-3 rounded border border-base-300">
                          <p class="text-sm font-medium text-base-content/80 mb-1">Comments:</p>
                          <p class="text-sm text-base-content/90"><%= evaluation.comments %></p>
                        </div>

                        <!-- Score Badge -->
                        <div class="flex justify-end mt-2">
                          <span class={"badge #{score_badge_class(evaluation.score)}"}>
                            <%= score_label(evaluation.score) %>
                          </span>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Programs -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title">Enrolled Programs</h3>
                  <div :if={@attachee_programs == []} class="text-center py-4">
                    <p class="text-base-content/50">No programs enrolled</p>
                  </div>
                  <div class="space-y-2" :if={@attachee_programs != []}>
                    <%= for program <- @attachee_programs do %>
                      <div class="p-3 bg-base-200 rounded-lg">
                        <p class="font-medium"><%= program.name %></p>
                        <p class="text-sm opacity-70"><%= program.code %></p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Current Tasks -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title">Current Tasks</h3>
                  <div :if={@attachee_tasks == []} class="text-center py-8">
                    <p class="text-base-content/50">No tasks assigned</p>
                  </div>
                  <div class="overflow-x-auto" :if={@attachee_tasks != []}>
                    <table class="table">
                      <thead>
                        <tr>
                          <th>Task</th>
                          <th>Project</th>
                          <th>Status</th>
                          <th>Due Date</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for task <- @attachee_tasks do %>
                          <tr>
                            <td>
                              <div>
                                <div class="font-medium"><%= task.title %></div>
                                <div class="text-sm opacity-70"><%= String.slice(task.description || "", 0..50) %></div>
                              </div>
                            </td>
                            <td><%= task.project.name %></td>
                            <td>
                              <span class={"badge #{task_status_badge(task.status)}"}>
                                <%= task.status %>
                              </span>
                            </td>
                            <td>
                              <%= if task.due_on do %>
                                <%= Calendar.strftime(task.due_on, "%b %d, %Y") %>
                              <% else %>
                                <span class="text-base-content/50">No due date</span>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              <!-- Task History -->
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h3 class="card-title">Recent Activity</h3>
                  <div class="space-y-3">
                    <%= for task <- Enum.take(@attachee_tasks, 5) do %>
                      <div class="flex items-center gap-3 p-3 bg-base-200 rounded-lg">
                        <div class={"w-2 h-2 rounded-full #{activity_indicator(task.status)}"}></div>
                        <div class="flex-1">
                          <p class="font-medium"><%= task.title %></p>
                          <p class="text-sm opacity-70">
                            <%= if task.updated_at do %>
                              Updated <%= Timex.from_now(task.updated_at) %>
                            <% else %>
                              Recently created
                            <% end %>
                          </p>
                        </div>
                        <span class={"badge badge-sm #{task_status_badge(task.status)}"}>
                          <%= task.status %>
                        </span>
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
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-24 w-24 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    <h3 class="text-xl font-bold mt-4">Select an Attachee</h3>
                    <p class="text-base-content/70 mt-2">Choose an attachee from the list to view their profile and performance</p>
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

  # === HELPER FUNCTIONS ===

  # Calculate attachee statistics
  defp calculate_attachee_stats(attachee) do
    tasks = Eams.list_tasks_for_attachee(attachee.id)

    completed = Enum.count(tasks, &(&1.status == "completed"))
    pending = Enum.count(tasks, &(&1.status == "pending"))
    submitted = Enum.count(tasks, &(&1.status == "submitted"))
    in_progress = Enum.count(tasks, &(&1.status == "in_progress"))
    total_tasks = length(tasks)

    completion_rate = if total_tasks > 0 do
      Float.round(completed / total_tasks * 100, 1)
    else
      0
    end

    %{
      total_tasks: total_tasks,
      completed: completed,
      pending: pending,
      submitted: submitted,
      in_progress: in_progress,
      completion_rate: completion_rate
    }
  end

  # Evaluation score helpers
  defp score_color_class(score) when score >= 81, do: "bg-success text-success-content"
  defp score_color_class(score) when score >= 61, do: "bg-info text-info-content"
  defp score_color_class(score) when score >= 41, do: "bg-warning text-warning-content"
  defp score_color_class(_), do: "bg-error text-error-content"

  defp score_badge_class(score) when score >= 81, do: "badge-success badge-lg"
  defp score_badge_class(score) when score >= 61, do: "badge-info badge-lg"
  defp score_badge_class(score) when score >= 41, do: "badge-warning badge-lg"
  defp score_badge_class(_), do: "badge-error badge-lg"

  defp score_label(score) when score >= 81, do: "Excellent"
  defp score_label(score) when score >= 61, do: "Good"
  defp score_label(score) when score >= 41, do: "Satisfactory"
  defp score_label(_), do: "Needs Improvement"

  # Status badge helpers
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
  defp activity_indicator(_), do: "bg-base-content/20"
end
