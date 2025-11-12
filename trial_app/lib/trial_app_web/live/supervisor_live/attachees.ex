defmodule TrialAppWeb.SupervisorLive.Attachees do
  use TrialAppWeb, :live_view
  import Ecto.Query
  alias TrialApp.{Eams, Orgs, Repo}
  alias TrialAppWeb.SupervisorLive.EvaluationForm

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    current_scope = socket.assigns.current_scope

    # Use active_role from scope (this changes when role switching)
    current_role = current_scope.active_role

    # Set page title based on ACTUAL current role (not user.role)
    page_title =
      if current_role in ["admin", "super_admin"] do
        "Attachee Evaluation"
      else
        "Manage Attachees"
      end

    {:ok,
     socket
     |> assign(:page_title, page_title)
     |> assign(:current_user, current_user)
     |> assign(:current_role, current_role)
     |> assign(:selected_attachee, nil)
     |> assign(:show_evaluation_form, false)
     |> assign(:evaluations, [])
     |> assign(:avg_score, 0.0)
     |> assign(:eval_count, 0)
     |> load_data(current_user, current_role)}
  end

  defp load_data(socket, user, role) do
    if role in ["admin", "super_admin"] do
      # ADMIN: Load all attachees in hierarchical structure
      hierarchy = build_attachee_hierarchy()
      socket
      |> assign(:hierarchy, hierarchy)
      |> assign(:total_attachees, count_attachees_in_hierarchy(hierarchy))
      |> assign(:is_admin, true)
    else
      # SUPERVISOR: Load only attachees in their projects
      attachee_list = load_supervisor_attachees(user.id)
      socket
      |> assign(:attachees, attachee_list)
      |> assign(:total_attachees, length(attachee_list))
      |> assign(:is_admin, false)
    end
  end

  # === ADMIN: Build Hierarchy - ALL ATTACHEES ===
  defp build_attachee_hierarchy do
    # Attachees are linked to projects through tasks, not directly
    # We need to get unique attachee-project combinations through tasks
    query = from(a in Eams.Attachee,
      join: t in Eams.Task, on: t.assignee_id == a.id,
      join: p in Eams.Project, on: t.project_id == p.id,
      join: pr in Eams.Program, on: pr.id == p.program_id,
      join: d in Orgs.Department, on: d.id == pr.department_id,
      join: o in Orgs.Organization, on: o.id == d.organization_id,
      distinct: [a.id, p.id],
      preload: [:user],
      select: %{
        attachee: a,
        project: p,
        program: pr,
        department: d,
        organization: o
      },
      order_by: [asc: o.name, asc: d.name, asc: pr.name, asc: p.name, asc: a.inserted_at]
    )

    Repo.all(query)
    |> Enum.group_by(& &1.organization)
    |> Enum.reject(&is_nil(elem(&1, 0)))
    |> Enum.map(fn {org, dept_data} ->
      %{
        type: :organization,
        name: org.name,
        id: org.id,
        children:
          dept_data
          |> Enum.group_by(& &1.department)
          |> Enum.reject(&is_nil(elem(&1, 0)))
          |> Enum.map(fn {dept, prog_data} ->
            %{
              type: :department,
              name: dept.name,
              id: dept.id,
              children:
                prog_data
                |> Enum.group_by(& &1.program)
                |> Enum.reject(&is_nil(elem(&1, 0)))
                |> Enum.map(fn {prog, proj_data} ->
                  %{
                    type: :program,
                    name: prog.name,
                    code: prog.code || "N/A",
                    id: prog.id,
                    children:
                      proj_data
                      |> Enum.group_by(& &1.project)
                      |> Enum.reject(&is_nil(elem(&1, 0)))
                      |> Enum.map(fn {proj, attachee_list} ->
                        %{
                          type: :project,
                          name: proj.name,
                          id: proj.id,
                          attachees: Enum.map(attachee_list, fn item ->
                            %{
                              id: item.attachee.id,
                              user: item.attachee.user,
                              status: item.attachee.user.status
                            }
                          end)
                        }
                      end)
                  }
                end)
            }
          end)
      }
    end)
  end

  defp count_attachees_in_hierarchy(hierarchy) do
    hierarchy
    |> Enum.flat_map(&extract_attachees/1)
    |> length()
  end

  defp extract_attachees(%{attachees: attachees}), do: attachees
  defp extract_attachees(%{children: children}), do: Enum.flat_map(children, &extract_attachees/1)
  defp extract_attachees(_), do: []

  # === SUPERVISOR: Load only attachees in their supervised projects ===
  defp load_supervisor_attachees(supervisor_id) do
    # First, try to get attachees from projects where user is supervisor
    query = from(a in Eams.Attachee,
      join: t in Eams.Task, on: t.assignee_id == a.id,
      join: p in Eams.Project, on: t.project_id == p.id,
      where: p.supervisor_id == ^supervisor_id,
      distinct: a.id,
      preload: [:user, :department, :organization]
    )

    result = Repo.all(query)

    if result == [] do
      # Fallback: load by department if no tasks assigned
      dept_id = get_supervisor_department_id(supervisor_id)
      if dept_id do
        from(a in Eams.Attachee,
          where: a.department_id == ^dept_id,
          preload: [:user, :department, :organization]
        )
        |> Repo.all()
      else
        []
      end
    else
      result
    end
  end

  defp get_supervisor_department_id(supervisor_id) do
    case Orgs.get_department_for_user(supervisor_id) do
      nil -> nil
      dept -> dept.id
    end
  end

  # === EVENT HANDLERS ===
  def handle_event("select_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id, %{preloads: [:user, :department, :organization]})

    # Get projects through tasks
    project_ids = from(t in Eams.Task,
      where: t.assignee_id == ^id,
      distinct: t.project_id,
      select: t.project_id
    ) |> Repo.all()

    # Load first project with program for display
    project = if length(project_ids) > 0 do
      Repo.get(Eams.Project, List.first(project_ids)) |> Repo.preload(:program)
    else
      nil
    end

    attachee = Map.put(attachee, :project, project)

    tasks = Eams.list_tasks_for_attachee(attachee.id)
    projects = Eams.list_projects_for_attachee(attachee.id)
    programs = Eams.list_programs_for_attachee(attachee.id)
    evaluations = Eams.list_evaluations_for_attachee(attachee.id, %{preloads: [:evaluator]})

    avg_score = Eams.get_average_evaluation_score(attachee.id) |> safe_round_decimal()
    eval_count = Eams.count_evaluations_for_attachee(attachee.id)
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

  def handle_event("close_profile", _, socket), do: {:noreply, assign(socket, :selected_attachee, nil)}
  def handle_event("toggle_evaluation_form", _, socket), do: {:noreply, assign(socket, :show_evaluation_form, !socket.assigns.show_evaluation_form)}
  def handle_event("close_modal", _, socket), do: {:noreply, assign(socket, :show_evaluation_form, false)}

  def handle_info({:evaluation_submitted, attachee_id}, socket) do
    attachee = Eams.get_attachee!(attachee_id, %{preloads: [:user, :department, :organization]})

    # Get projects through tasks
    project_ids = from(t in Eams.Task,
      where: t.assignee_id == ^attachee_id,
      distinct: t.project_id,
      select: t.project_id
    ) |> Repo.all()

    # Load first project with program for display
    project = if length(project_ids) > 0 do
      Repo.get(Eams.Project, List.first(project_ids)) |> Repo.preload(:program)
    else
      nil
    end

    attachee = Map.put(attachee, :project, project)

    evaluations = Eams.list_evaluations_for_attachee(attachee_id, %{preloads: [:evaluator]})
    avg_score = Eams.get_average_evaluation_score(attachee_id) |> safe_round_decimal()
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

  def handle_info({:close_modal, _}, socket), do: {:noreply, assign(socket, :show_evaluation_form, false)}
  def handle_info(:close_modal, socket), do: {:noreply, assign(socket, :show_evaluation_form, false)}

  defp safe_round_decimal(nil), do: 0.0
  defp safe_round_decimal(%Decimal{} = d), do: d |> Decimal.round(1) |> Decimal.to_float()
  defp safe_round_decimal(n) when is_number(n), do: Float.round(n, 1)
  defp safe_round_decimal(_), do: 0.0

  defp calculate_attachee_stats(attachee) do
    tasks = Eams.list_tasks_for_attachee(attachee.id)
    total_tasks = length(tasks)
    completed = Enum.count(tasks, &(&1.status == "completed"))
    completion_rate = if total_tasks > 0, do: (completed * 100.0 / total_tasks) |> Float.round(1), else: 0.0

    %{
      total_tasks: total_tasks,
      completed: completed,
      pending: Enum.count(tasks, &(&1.status == "pending")),
      submitted: Enum.count(tasks, &(&1.status == "submitted")),
      in_progress: Enum.count(tasks, &(&1.status == "in_progress")),
      completion_rate: completion_rate
    }
  end

  defp status_badge("active"), do: "badge-success"
  defp status_badge("inactive"), do: "badge-error"
  defp status_badge(_), do: "badge-ghost"

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="lg:ml-64 p-8">
        <div class="max-w-7xl mx-auto">
          <!-- Header -->
          <div class="mb-8">
            <h1 class="text-3xl font-bold"><%= @page_title %></h1>
            <p class="text-base-content/70">
              <%= if @is_admin do %>
                Evaluate all attachees across all projects and departments
              <% else %>
                View and manage attachees under your supervision
              <% end %>
            </p>
          </div>

          <!-- Stats -->
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
                  <%= if @is_admin do %>
                    <%= Enum.count(Enum.flat_map(@hierarchy, &extract_attachees/1), &(&1.status == "active")) %>
                  <% else %>
                    <%= Enum.count(@attachees, &(&1.user.status == "active")) %>
                  <% end %>
                </p>
              </div>
            </div>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">
                  <%= if @is_admin do %>
                    Inactive
                  <% else %>
                    Selected
                  <% end %>
                </p>
                <p class="text-3xl font-bold text-warning">
                  <%= if @is_admin do %>
                    <%= Enum.count(Enum.flat_map(@hierarchy, &extract_attachees/1), &(&1.status != "active")) %>
                  <% else %>
                    <%= if @selected_attachee, do: "1", else: "0" %>
                  <% end %>
                </p>
              </div>
            </div>
          </div>

          <!-- ADMIN VIEW: Hierarchy of ALL attachees -->
          <%= if @is_admin do %>
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <!-- Left: Hierarchy -->
              <div class="lg:col-span-1 space-y-4 max-h-[800px] overflow-y-auto">
                <%= for org <- @hierarchy do %>
                  <div class="card bg-base-100 shadow-xl">
                    <div class="card-body p-4">
                      <div class="flex items-center gap-2 mb-3">
                        <div class="w-8 h-8 bg-purple-600 rounded-full flex items-center justify-center text-white font-bold text-xs">
                          O
                        </div>
                        <h2 class="font-bold text-sm"><%= org.name %></h2>
                      </div>

                      <div class="ml-6 space-y-3">
                        <%= for dept <- org.children do %>
                          <div>
                            <div class="flex items-center gap-2 mb-2">
                              <div class="w-6 h-6 bg-blue-600 rounded-full flex items-center justify-center text-white text-xs font-bold">
                                D
                              </div>
                              <h3 class="font-semibold text-xs"><%= dept.name %></h3>
                            </div>

                            <div class="ml-5 space-y-2">
                              <%= for prog <- dept.children do %>
                                <div>
                                  <div class="flex items-center gap-2 mb-2">
                                    <div class="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center text-white text-xs font-bold">
                                      P
                                    </div>
                                    <h4 class="font-medium text-xs"><%= prog.name %></h4>
                                  </div>

                                  <div class="ml-4 space-y-2">
                                    <%= for proj <- prog.children do %>
                                      <div class="border-l-2 border-base-300 pl-3">
                                        <div class="flex items-center gap-1 mb-1">
                                          <div class="w-4 h-4 bg-orange-600 rounded-full flex items-center justify-center text-white" style="font-size: 8px;">
                                            PJ
                                          </div>
                                          <h5 class="font-medium text-xs"><%= proj.name %></h5>
                                        </div>

                                        <div class="ml-3 space-y-1">
                                          <%= for att <- proj.attachees do %>
                                            <div
                                              phx-click="select_attachee"
                                              phx-value-id={att.id}
                                              class={"p-2 rounded-lg cursor-pointer transition-all #{if @selected_attachee && @selected_attachee.id == att.id, do: "bg-primary text-white", else: "hover:bg-base-200"}"}
                                            >
                                              <div class="flex items-center gap-2">
                                                <div class="avatar placeholder">
                                                  <div class={"w-8 h-8 rounded-full #{if @selected_attachee && @selected_attachee.id == att.id, do: "bg-primary-content text-primary", else: "bg-neutral text-neutral-content"}"}>
                                                    <span class="text-xs">
                                                      <%= String.first(att.user.username || att.user.email) |> String.upcase() %>
                                                    </span>
                                                  </div>
                                                </div>
                                                <div class="flex-1 min-w-0">
                                                  <p class="font-medium text-xs truncate"><%= att.user.username || att.user.email %></p>
                                                </div>
                                                <div class={"badge badge-xs #{status_badge(att.status)}"}>
                                                  <%= att.status %>
                                                </div>
                                              </div>
                                            </div>
                                          <% end %>
                                        </div>
                                      </div>
                                    <% end %>
                                  </div>
                                </div>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Right: Selected Attachee Profile (Admin) -->
              <%= if @selected_attachee do %>
                <div class="lg:col-span-2 space-y-6">
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
                        <div>
                          <p class="text-sm text-base-content/70">Project</p>
                          <p class="font-medium"><%= if @selected_attachee.project, do: @selected_attachee.project.name, else: "N/A" %></p>
                        </div>
                        <div>
                          <p class="text-sm text-base-content/70">Program</p>
                          <p class="font-medium"><%= if @selected_attachee.project && @selected_attachee.project.program, do: @selected_attachee.project.program.name, else: "N/A" %></p>
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
                </div>
              <% else %>
                <!-- No Selection (Admin) -->
                <div class="lg:col-span-2">
                  <div class="card bg-base-100 shadow-xl h-full">
                    <div class="card-body flex items-center justify-center">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-24 w-24 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <h3 class="text-xl font-bold mt-4">Select an Attachee to Evaluate</h3>
                        <p class="text-base-content/70 mt-2">Browse the hierarchy and click on any attachee to view their profile and evaluation history</p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <!-- SUPERVISOR VIEW: Only their attachees -->
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <div class="lg:col-span-1 card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title">Your Attachees</h2>
                  <div :if={@attachees == []} class="text-center py-8">
                    <p class="text-base-content/50">No attachees found</p>
                    <p class="text-sm text-base-content/40 mt-1">Attachees will appear here when assigned to your projects</p>
                  </div>
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
                            <p class="text-sm opacity-70"><%= attachee.department.name %></p>
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

              <!-- Profile Section (Supervisor) -->
              <%= if @selected_attachee do %>
                <div class="lg:col-span-2 space-y-6">
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
                        <div>
                          <p class="text-sm text-base-content/70">Project</p>
                          <p class="font-medium"><%= if @selected_attachee.project, do: @selected_attachee.project.name, else: "N/A" %></p>
                        </div>
                        <div>
                          <p class="text-sm text-base-content/70">Program</p>
                          <p class="font-medium"><%= if @selected_attachee.project && @selected_attachee.project.program, do: @selected_attachee.project.program.name, else: "N/A" %></p>
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
                </div>
              <% end %>

              <!-- No Selection (Supervisor) -->
              <%= if !@selected_attachee do %>
                <div class="lg:col-span-2">
                  <div class="card bg-base-100 shadow-xl h-full">
                    <div class="card-body flex items-center justify-center">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-24 w-24 mx-auto text-base-content/20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                        <h3 class="text-xl font-bold mt-4">Select an Attachee</h3>
                        <p class="text-base-content/70 mt-2">Choose an attachee from the list to view their profile and manage their tasks</p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
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
end
