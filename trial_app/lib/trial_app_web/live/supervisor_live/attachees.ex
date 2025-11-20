defmodule TrialAppWeb.SupervisorLive.Attachees do
  use TrialAppWeb, :live_view
  import Ecto.Query
  alias TrialApp.{Eams, Orgs, Repo}
  alias TrialAppWeb.SupervisorLive.EvaluationForm
  import Timex.Format.DateTime.Formatter

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    current_scope = socket.assigns.current_scope
    current_role = current_scope.active_role

    page_title =
      if current_role in ["admin", "super_admin"],
        do: "Attachee Evaluation",
        else: "Manage Attachees"

    socket =
      socket
      |> assign(:filter_search, "")
      |> assign(:group_by, "none")
      |> assign(:page_title, page_title)
      |> assign(:current_user, current_user)
      |> assign(:current_role, current_role)
      |> assign(:selected_attachee, nil)
      |> assign(:show_evaluation_form, false)
      |> assign(:evaluations, [])
      |> assign(:avg_score, 0.0)
      |> assign(:eval_count, 0)
      |> assign(:attachee_tasks, [])
      |> assign(:attachee_projects, [])
      |> assign(:task_scores, %{})
      |> assign(:profile_tab, "overview")
      # Exactly 7 criteria for non-task evaluation items
      |> assign(:evaluation_criteria, [
        "Teamwork",
        "Communication",
        "Problem Solving",
        "Initiative",
        "Time Management",
        "Professionalism",
        "Technical Skills"
      ])

    socket = load_data(socket, current_user, current_role)

    {:ok, socket}
  end

  # --------------------- FILTER EVENTS ---------------------
  def handle_event("filter_search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :filter_search, search)}
  end

  def handle_event("change_grouping", %{"grouping" => grouping}, socket) do
    {:noreply, assign(socket, :group_by, grouping)}
  end

  def handle_event("clear_filters", _params, socket) do
    user = socket.assigns.current_user
    role = socket.assigns.current_role

    {:noreply,
     socket
     |> assign(:filter_search, "")
     |> assign(:group_by, "none")
     |> assign(:selected_attachee, nil)
     |> assign(:show_evaluation_form, false)
     |> assign(:evaluations, [])
     |> assign(:avg_score, 0.0)
     |> assign(:eval_count, 0)
     |> assign(:attachee_tasks, [])
     |> assign(:attachee_projects, [])
     |> assign(:task_scores, %{})
     |> assign(:profile_tab, "overview")
     |> load_data(user, role)}
  end

  # Tab switching inside attachee profile
  def handle_event("change_profile_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :profile_tab, tab)}
  end

  # --------------------- DATA LOADING ---------------------
  defp load_data(socket, user, role) do
    if role in ["admin", "super_admin"] do
      all_attachees = load_all_attachees()

      socket
      |> assign(:all_attachees, all_attachees)
      |> assign(:total_attachees, length(all_attachees))
      |> assign(:is_admin, true)
    else
      attachee_list = load_supervisor_attachees(user.id)

      socket
      |> assign(:all_attachees, attachee_list)
      |> assign(:total_attachees, length(attachee_list))
      |> assign(:is_admin, false)
    end
  end

  # --------------------- LOAD ALL ATTACHEES FOR ADMIN ---------------------
  defp load_all_attachees do
    query =
      from a in Eams.Attachee,
        join: t in Eams.Task, on: t.assignee_id == a.id,
        join: p in Eams.Project, on: t.project_id == p.id,
        join: pr in Eams.Program, on: pr.id == p.program_id,
        join: d in Orgs.Department, on: d.id == pr.department_id,
        join: o in Orgs.Organization, on: o.id == d.organization_id,
        distinct: a.id,
        preload: [:user],
        select: %{
          attachee: a,
          project: p,
          program: pr,
          department: d,
          organization: o
        },
        order_by: [asc: a.inserted_at]

    Repo.all(query)
    |> Enum.map(fn item ->
      %{
        id: item.attachee.id,
        user: item.attachee.user,
        status: item.attachee.user.status,
        organization: item.organization,
        department: item.department,
        program: item.program,
        project: item.project,
        project_name: item.project.name,
        department_name: item.department.name,
        program_name: item.program.name
      }
    end)
  end

  # --------------------- SUPERVISOR ATTACHEES ---------------------
  defp load_supervisor_attachees(supervisor_id) do
    query =
      from a in Eams.Attachee,
        join: t in Eams.Task, on: t.assignee_id == a.id,
        join: p in Eams.Project, on: t.project_id == p.id,
        where: p.supervisor_id == ^supervisor_id,
        distinct: a.id,
        preload: [:user, :department, :organization]

    result = Repo.all(query)

    if result == [] do
      dept_id = get_supervisor_department_id(supervisor_id)

      if dept_id do
        from(a in Eams.Attachee,
          where: a.department_id == ^dept_id,
          preload: [:user, :department, :organization]
        )
        |> Repo.all()
        |> Enum.map(fn attachee ->
          %{
            id: attachee.id,
            user: attachee.user,
            status: attachee.user.status,
            organization: attachee.organization,
            department: attachee.department,
            program: nil,
            project: nil,
            project_name: "N/A",
            department_name: attachee.department.name,
            program_name: "N/A"
          }
        end)
      else
        []
      end
    else
      Enum.map(result, fn attachee ->
        project_ids =
          from(t in Eams.Task,
            where: t.assignee_id == ^attachee.id,
            distinct: t.project_id,
            select: t.project_id
          )
          |> Repo.all()

        project =
          if length(project_ids) > 0 do
            Repo.get(Eams.Project, hd(project_ids)) |> Repo.preload(:program)
          else
            nil
          end

        %{
          id: attachee.id,
          user: attachee.user,
          status: attachee.user.status,
          organization: attachee.organization,
          department: attachee.department,
          program: if(project && project.program, do: project.program, else: nil),
          project: project,
          project_name: if(project, do: project.name, else: "N/A"),
          department_name: attachee.department.name,
          program_name: if(project && project.program, do: project.program.name, else: "N/A")
        }
      end)
    end
  end

  defp get_supervisor_department_id(supervisor_id) do
    case Orgs.get_department_for_user(supervisor_id) do
      nil -> nil
      dept -> dept.id
    end
  end

  # --------------------- ATTACHEE SELECTION ---------------------
  def handle_event("select_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id, %{preloads: [:user, :department, :organization]})

    project_ids =
      from(t in Eams.Task,
        where: t.assignee_id == ^id,
        distinct: t.project_id,
        select: t.project_id
      )
      |> Repo.all()

    projects =
      if project_ids == [] do
        []
      else
        from(p in Eams.Project,
          where: p.id in ^project_ids,
          preload: [:program]
        )
        |> Repo.all()
      end

    primary_project = List.first(projects)

    attachee = Map.put(attachee, :project, primary_project)

    tasks = Eams.list_tasks_for_attachee(attachee.id)
    evaluations = Eams.list_evaluations_for_attachee(attachee.id, %{preloads: [:evaluator]})

    avg_score =
      Eams.get_average_evaluation_score(attachee.id)
      |> safe_round_decimal()

    eval_count = Eams.count_evaluations_for_attachee(attachee.id)
    stats = calculate_attachee_stats(attachee)

    task_scores = build_task_scores(evaluations)

    {:noreply,
     socket
     |> assign(:selected_attachee, attachee)
     |> assign(:attachee_tasks, tasks)
     |> assign(:attachee_projects, projects)
     |> assign(:task_scores, task_scores)
     |> assign(:attachee_stats, stats)
     |> assign(:evaluations, evaluations)
     |> assign(:avg_score, avg_score)
     |> assign(:eval_count, eval_count)
     |> assign(:profile_tab, "overview")}
  end

  def handle_event("close_profile", _, socket),
    do:
      {:noreply,
       socket
       |> assign(:selected_attachee, nil)
       |> assign(:attachee_tasks, [])
       |> assign(:attachee_projects, [])
       |> assign(:task_scores, %{})
       |> assign(:profile_tab, "overview")}

  def handle_event("toggle_evaluation_form", _, socket),
    do: {:noreply, assign(socket, :show_evaluation_form, !socket.assigns.show_evaluation_form)}

  def handle_event("close_modal", _, socket),
    do: {:noreply, assign(socket, :show_evaluation_form, false)}

  def handle_info({:evaluation_submitted, attachee_id}, socket) do
    send(self(), {:select_attachee, attachee_id})
    {:noreply, put_flash(socket, :info, "Evaluation submitted successfully!")}
  end

  def handle_info({:select_attachee, id}, socket) do
    handle_event("select_attachee", %{"id" => to_string(id)}, socket)
  end

  def handle_info({:close_modal, _}, socket),
    do: {:noreply, assign(socket, :show_evaluation_form, false)}

  def handle_info(:close_modal, socket),
    do: {:noreply, assign(socket, :show_evaluation_form, false)}

  # --------------------- HELPERS ---------------------
  defp safe_round_decimal(nil), do: 0.0
  defp safe_round_decimal(%Decimal{} = d), do: d |> Decimal.round(1) |> Decimal.to_float()
  defp safe_round_decimal(n) when is_number(n), do: Float.round(n, 1)
  defp safe_round_decimal(_), do: 0.0

  defp calculate_attachee_stats(attachee) do
    tasks = Eams.list_tasks_for_attachee(attachee.id)
    total_tasks = length(tasks)
    completed = Enum.count(tasks, &(&1.status == "completed"))

    completion_rate =
      if total_tasks > 0,
        do: Float.round(completed * 100.0 / total_tasks, 1),
        else: 0.0

    %{
      total_tasks: total_tasks,
      completed: completed,
      pending: Enum.count(tasks, &(&1.status == "pending")),
      submitted: Enum.count(tasks, &(&1.status == "submitted")),
      in_progress: Enum.count(tasks, &(&1.status == "in_progress")),
      completion_rate: completion_rate
    }
  end

  # Build task score map from evaluations (expects evaluations to have :task_id)
  defp build_task_scores(evaluations) do
    evaluations
    |> Enum.filter(fn eval ->
      Map.has_key?(eval, :task_id) && eval.task_id
    end)
    |> Enum.group_by(& &1.task_id)
    |> Enum.into(%{}, fn {task_id, evals} ->
      latest = Enum.max_by(evals, & &1.inserted_at)
      {task_id, %{score: latest.score, label: score_label(latest.score)}}
    end)
  end

  # --------------------- STYLING ---------------------
  defp status_color("active"), do: "bg-green-100 text-green-800"
  defp status_color("inactive"), do: "bg-red-100 text-red-800"
  defp status_color("completed"), do: "bg-blue-100 text-blue-800"
  defp status_color("suspended"), do: "bg-orange-100 text-orange-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp status_badge("active"), do: "badge-success"
  defp status_badge("inactive"), do: "badge-warning"
  defp status_badge("suspended"), do: "badge-error"
  defp status_badge(_), do: "badge-ghost"

  defp score_color_class(score) when score >= 81, do: "bg-success text-success-content"
  defp score_color_class(score) when score >= 61, do: "bg-info text-info-content"
  defp score_color_class(score) when score >= 41, do: "bg-warning text-warning-content"
  defp score_color_class(_), do: "bg-error text-error-content"

  defp score_badge_class(score) when score >= 81, do: "badge-success badge-lg"
  defp score_badge_class(score) when score >= 61, do: "badge-info badge-lg"
  defp score_badge_class(score) when score >= 41, do: "badge-warning badge-lg"
  defp score_badge_class(_), do: "badge-error badge-lg"

  defp score_bg_color(score) when score >= 81, do: "bg-green-600 text-white"
  defp score_bg_color(score) when score >= 61, do: "bg-blue-600 text-white"
  defp score_bg_color(score) when score >= 41, do: "bg-amber-600 text-white"
  defp score_bg_color(_), do: "bg-red-600 text-white"

  defp score_label(score) when score >= 81, do: "Excellent"
  defp score_label(score) when score >= 61, do: "Good"
  defp score_label(score) when score >= 41, do: "Satisfactory"
  defp score_label(_), do: "Needs Improvement"

  # --------------------- FILTER HELPERS ---------------------
  defp filter_by_search(list, search) when search == "" or is_nil(search), do: list

  defp filter_by_search(list, search) do
    term = String.downcase(search)

    Enum.filter(list, fn a ->
      name = (a.user.username || a.user.email || "") |> String.downcase()
      email = (a.user.email || "") |> String.downcase()
      dept = (a.department_name || "") |> String.downcase()
      proj = (a.project_name || "") |> String.downcase()
      prog = (a.program_name || "") |> String.downcase()

      String.contains?(name, term) or
        String.contains?(email, term) or
        String.contains?(dept, term) or
        String.contains?(proj, term) or
        String.contains?(prog, term)
    end)
  end

  defp get_filtered_attachees(all_attachees, search) do
    filter_by_search(all_attachees, search)
  end

  defp group_attachees(attachees, "none"), do: %{"All Attachees" => attachees}

  defp group_attachees(attachees, "department") do
    attachees
    |> Enum.group_by(& &1.department_name)
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.into(%{})
  end

  defp group_attachees(attachees, "program") do
    attachees
    |> Enum.group_by(& &1.program_name)
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.into(%{})
  end

  defp group_attachees(attachees, "project") do
    attachees
    |> Enum.group_by(& &1.project_name)
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.into(%{})
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <!-- Sidebar -->
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <!-- Main content -->
        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-8">
            <!-- Header -->
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-semibold text-gray-800"><%= @page_title %></h1>
                <p class="text-sm text-gray-500 mt-1">
                  <%= if @is_admin do %>
                    Evaluate all attachees across all projects and departments
                  <% else %>
                    View and manage attachees under your supervision
                  <% end %>
                </p>
              </div>
            </div>

            <!-- Stats Summary -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="bg-purple-50 p-4 rounded-lg border border-purple-100">
                <div class="text-sm text-purple-600 font-medium">Total Attachees</div>
                <div class="text-2xl font-bold text-purple-700 mt-1"><%= @total_attachees %></div>
              </div>
              <div class="bg-green-50 p-4 rounded-lg border border-green-100">
                <div class="text-sm text-green-600 font-medium">Active</div>
                <div class="text-2xl font-bold text-green-700 mt-1">
                  <%= Enum.count(@all_attachees, &(&1.status == "active")) %>
                </div>
              </div>
              <div class="bg-amber-50 p-4 rounded-lg border border-amber-100">
                <div class="text-sm text-amber-600 font-medium">
                  <%= if @is_admin do %>
                    Inactive
                  <% else %>
                    Selected
                  <% end %>
                </div>
                <div class="text-2xl font-bold text-amber-700 mt-1">
                  <%= if @is_admin do %>
                    <%= Enum.count(@all_attachees, &(&1.status != "active")) %>
                  <% else %>
                    <%= if @selected_attachee, do: "1", else: "0" %>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <!-- Left: Attachees List with Search and Grouping -->
              <div class="lg:col-span-1 bg-white shadow rounded-xl overflow-hidden">
                <div class="px-4 py-3 bg-gray-100 border-b border-gray-200">
                  <h2 class="text-sm font-semibold text-gray-800 mb-3">
                    <%= if @is_admin, do: "All Attachees", else: "Your Attachees" %>
                  </h2>

                  <!-- Search Bar -->
                  <div class="relative mb-3">
                    <input
                      type="text"
                      phx-keyup="filter_search"
                      phx-debounce="300"
                      name="search"
                      value={@filter_search}
                      placeholder="Search by name, email, dept, project..."
                      class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    />
                    <%= if @filter_search != "" do %>
                      <button
                        phx-click="clear_filters"
                        class="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                      >
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    <% end %>
                  </div>

                  <!-- Group By Buttons -->
                  <div class="flex gap-2 flex-wrap">
                    <button
                      phx-click="change_grouping"
                      phx-value-grouping="none"
                      class={[
                        "px-3 py-1 text-xs rounded-full font-medium transition",
                        @group_by == "none" && "bg-purple-600 text-white",
                        @group_by != "none" && "bg-gray-200 text-gray-700 hover:bg-gray-300"
                      ]}
                    >
                      All
                    </button>
                    <button
                      phx-click="change_grouping"
                      phx-value-grouping="department"
                      class={[
                        "px-3 py-1 text-xs rounded-full font-medium transition",
                        @group_by == "department" && "bg-purple-600 text-white",
                        @group_by != "department" && "bg-gray-200 text-gray-700 hover:bg-gray-300"
                      ]}
                    >
                      By Department
                    </button>
                    <button
                      phx-click="change_grouping"
                      phx-value-grouping="program"
                      class={[
                        "px-3 py-1 text-xs rounded-full font-medium transition",
                        @group_by == "program" && "bg-purple-600 text-white",
                        @group_by != "program" && "bg-gray-200 text-gray-700 hover:bg-gray-300"
                      ]}
                    >
                      By Program
                    </button>
                    <button
                      phx-click="change_grouping"
                      phx-value-grouping="project"
                      class={[
                        "px-3 py-1 text-xs rounded-full font-medium transition",
                        @group_by == "project" && "bg-purple-600 text-white",
                        @group_by != "project" && "bg-gray-200 text-gray-700 hover:bg-gray-300"
                      ]}
                    >
                      By Project
                    </button>
                  </div>
                </div>

                <div class="p-4 space-y-4 max-h-[800px] overflow-y-auto">
                  <%= for {group_name, attachees} <- group_attachees(get_filtered_attachees(@all_attachees, @filter_search), @group_by) do %>
                    <%= if @group_by != "none" do %>
                      <div class="mb-2">
                        <h3 class="text-xs font-bold text-gray-600 uppercase tracking-wide mb-2 flex items-center gap-2">
                          <span class="w-2 h-2 bg-purple-600 rounded-full"></span>
                          <%= group_name %>
                          <span class="text-xs font-normal text-gray-500">(<%= length(attachees) %>)</span>
                        </h3>
                      </div>
                    <% end %>

                    <div class="space-y-2">
                      <%= for attachee <- attachees do %>
                        <div
                          phx-click="select_attachee"
                          phx-value-id={attachee.id}
                          class={[
                            "p-3 rounded-lg cursor-pointer transition-all border",
                            @selected_attachee && @selected_attachee.id == attachee.id && "bg-purple-600 text-white border-purple-600",
                            !(@selected_attachee && @selected_attachee.id == attachee.id) && "bg-white hover:bg-gray-50 border-gray-200"
                          ]}
                        >
                          <div class="flex items-center gap-3">
                            <div class={[
                              "w-10 h-10 rounded-full flex items-center justify-center text-sm font-medium flex-shrink-0",
                              @selected_attachee && @selected_attachee.id == attachee.id && "bg-white text-purple-600",
                              !(@selected_attachee && @selected_attachee.id == attachee.id) && "bg-purple-100 text-purple-700"
                            ]}>
                              <%= String.first(attachee.user.username || attachee.user.email) |> String.upcase() %>
                            </div>
                            <div class="flex-1 min-w-0">
                              <p class="font-medium text-sm truncate"><%= attachee.user.username || attachee.user.email %></p>
                              <p class={[
                                "text-xs truncate",
                                @selected_attachee && @selected_attachee.id == attachee.id && "text-purple-100",
                                !(@selected_attachee && @selected_attachee.id == attachee.id) && "text-gray-500"
                              ]}>
                                <%= attachee.department_name %> • <%= attachee.project_name %>
                              </p>
                            </div>
                            <span class={[
                              "inline-flex items-center px-2 py-0.5 text-xs rounded-full font-medium flex-shrink-0",
                              @selected_attachee && @selected_attachee.id == attachee.id && "bg-white text-purple-600",
                              !(@selected_attachee && @selected_attachee.id == attachee.id) && status_color(attachee.status)
                            ]}>
                              <%= String.capitalize(attachee.status) %>
                            </span>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <%= if get_filtered_attachees(@all_attachees, @filter_search) == [] do %>
                    <div class="text-center py-12">
                      <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                      <p class="text-gray-500 font-medium">No attachees found</p>
                      <p class="text-sm text-gray-400 mt-1">Try adjusting your search</p>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Right: Selected Attachee Profile -->
              <%= if @selected_attachee do %>
                <div class="lg:col-span-2 space-y-6">
                  <!-- Profile Card -->
                  <div class="bg-white shadow rounded-xl overflow-hidden">
                    <div class="p-6">
                      <div class="flex justify-between items-start mb-4">
                        <div class="flex items-center gap-4">
                          <div class="w-16 h-16 rounded-full bg-purple-600 flex items-center justify-center text-white text-2xl font-bold">
                            <%= String.first(@selected_attachee.user.username || @selected_attachee.user.email) |> String.upcase() %>
                          </div>
                          <div>
                            <h2 class="text-2xl font-bold text-gray-900"><%= @selected_attachee.user.username || @selected_attachee.user.email %></h2>
                            <p class="text-sm text-gray-500 mt-1"><%= @selected_attachee.user.email %></p>
                            <div class="flex gap-2 mt-2">
                              <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(@selected_attachee.user.status)}"}>
                                <%= String.capitalize(@selected_attachee.user.status) %>
                              </span>
                            </div>
                          </div>
                        </div>
                        <div class="flex gap-2">
                          <button
                            phx-click="toggle_evaluation_form"
                            class="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition shadow"
                          >
                            Evaluate
                          </button>
                          <button
                            phx-click="close_profile"
                            class="px-4 py-2 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-100 transition border border-gray-300"
                          >
                            Close
                          </button>
                        </div>
                      </div>

                      <!-- Info Grid -->
                      <div class="grid grid-cols-2 gap-4 mt-6 pt-6 border-t border-gray-200">
                        <div>
                          <p class="text-xs text-gray-500 font-medium uppercase">Department</p>
                          <p class="text-sm font-semibold text-gray-900 mt-1"><%= @selected_attachee.department.name %></p>
                        </div>
                        <div>
                          <p class="text-xs text-gray-500 font-medium uppercase">Organization</p>
                          <p class="text-sm font-semibold text-gray-900 mt-1"><%= @selected_attachee.organization.name %></p>
                        </div>
                        <div>
                          <p class="text-xs text-gray-500 font-medium uppercase">Primary Project</p>
                          <p class="text-sm font-semibold text-gray-900 mt-1"><%= if @selected_attachee.project, do: @selected_attachee.project.name, else: "N/A" %></p>
                        </div>
                        <div>
                          <p class="text-xs text-gray-500 font-medium uppercase">Program</p>
                          <p class="text-sm font-semibold text-gray-900 mt-1">
                            <%= if @selected_attachee.project && @selected_attachee.project.program, do: @selected_attachee.project.program.name, else: "N/A" %>
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Profile Tabs -->
                  <div class="flex gap-2 border-b border-gray-200">
                    <button
                      phx-click="change_profile_tab"
                      phx-value-tab="overview"
                      class={[
                        "px-4 py-2 text-sm font-medium border-b-2 -mb-px",
                        @profile_tab == "overview" && "border-purple-600 text-purple-700",
                        @profile_tab != "overview" && "border-transparent text-gray-500 hover:text-gray-700"
                      ]}
                    >
                      Overview
                    </button>
                    <button
                      phx-click="change_profile_tab"
                      phx-value-tab="projects"
                      class={[
                        "px-4 py-2 text-sm font-medium border-b-2 -mb-px",
                        @profile_tab == "projects" && "border-purple-600 text-purple-700",
                        @profile_tab != "projects" && "border-transparent text-gray-500 hover:text-gray-700"
                      ]}
                    >
                      Projects
                    </button>
                    <button
                      phx-click="change_profile_tab"
                      phx-value-tab="tasks"
                      class={[
                        "px-4 py-2 text-sm font-medium border-b-2 -mb-px",
                        @profile_tab == "tasks" && "border-purple-600 text-purple-700",
                        @profile_tab != "tasks" && "border-transparent text-gray-500 hover:text-gray-700"
                      ]}
                    >
                      Tasks & Scores
                    </button>
                  </div>

                  <!-- Overview Tab: Performance + Evaluation History -->
                  <%= if @profile_tab == "overview" do %>
                    <!-- Performance Stats -->
                    <div class="bg-white shadow rounded-xl overflow-hidden">
                      <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-semibold text-gray-900">Performance Overview</h3>
                      </div>
                      <div class="p-6">
                        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                          <div class="bg-gray-50 p-4 rounded-lg border border-gray-200">
                            <p class="text-xs text-gray-500 font-medium uppercase">Total Tasks</p>
                            <p class="text-2xl font-bold text-gray-900 mt-2"><%= @attachee_stats.total_tasks %></p>
                          </div>
                          <div class="bg-green-50 p-4 rounded-lg border border-green-200">
                            <p class="text-xs text-green-600 font-medium uppercase">Completed</p>
                            <p class="text-2xl font-bold text-green-700 mt-2"><%= @attachee_stats.completed %></p>
                          </div>
                          <div class="bg-amber-50 p-4 rounded-lg border border-amber-200">
                            <p class="text-xs text-amber-600 font-medium uppercase">Pending</p>
                            <p class="text-2xl font-bold text-amber-700 mt-2"><%= @attachee_stats.pending %></p>
                          </div>
                          <div class="bg-blue-50 p-4 rounded-lg border border-blue-200">
                            <p class="text-xs text-blue-600 font-medium uppercase">Submitted</p>
                            <p class="text-2xl font-bold text-blue-700 mt-2"><%= @attachee_stats.submitted %></p>
                          </div>
                        </div>

                        <!-- Completion Rate -->
                        <div class="mt-6">
                          <div class="flex justify-between items-center mb-2">
                            <span class="text-sm font-medium text-gray-700">Completion Rate</span>
                            <span class="text-sm font-bold text-gray-900"><%= @attachee_stats.completion_rate %>%</span>
                          </div>
                          <div class="w-full bg-gray-200 rounded-full h-2.5">
                            <div
                              class="bg-green-600 h-2.5 rounded-full transition-all"
                              style={"width: #{@attachee_stats.completion_rate}%"}
                            ></div>
                          </div>
                        </div>
                      </div>
                    </div>

                    <!-- Evaluation History -->
                    <div class="bg-white shadow rounded-xl overflow-hidden">
                      <div class="px-6 py-4 border-b border-gray-200">
                        <div class="flex justify-between items-center">
                          <h3 class="text-lg font-semibold text-gray-900">Evaluation History</h3>
                          <div class="flex items-center gap-6">
                            <div class="text-center">
                              <div class="text-2xl font-bold text-purple-600"><%= @avg_score %></div>
                              <div class="text-xs text-gray-500 uppercase">Average Score</div>
                            </div>
                            <div class="text-center">
                              <div class="text-2xl font-bold text-gray-900"><%= @eval_count %></div>
                              <div class="text-xs text-gray-500 uppercase">Total Evaluations</div>
                            </div>
                          </div>
                        </div>
                      </div>

                      <div class="p-6">
                        <%= if @evaluations == [] do %>
                          <div class="text-center py-12">
                            <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            <p class="text-gray-500 font-medium">No evaluations yet</p>
                            <p class="text-sm text-gray-400 mt-1">Click "Evaluate" to submit the first evaluation</p>
                          </div>
                        <% else %>
                          <div class="space-y-4 max-h-96 overflow-y-auto">
                            <%= for evaluation <- @evaluations do %>
                              <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition">
                                <div class="flex justify-between items-start mb-3">
                                  <div class="flex items-center gap-3">
                                    <div class={"w-12 h-12 rounded-full flex items-center justify-center text-xl font-bold #{score_bg_color(evaluation.score)}"}>
                                      <%= evaluation.score %>
                                    </div>
                                    <div>
                                      <p class="font-semibold text-gray-900">
                                        Score: <%= evaluation.score %>/100
                                      </p>
                                      <p class="text-sm text-gray-500">
                                        by <%= evaluation.evaluator.username || evaluation.evaluator.email %>
                                      </p>
                                    </div>
                                  </div>
                                  <div class="text-right">
                                    <p class="text-sm text-gray-700 font-medium">
                                      <%= Calendar.strftime(evaluation.inserted_at, "%b %d, %Y") %>
                                    </p>
                                    <p class="text-xs text-gray-500">
                                      <%= Timex.from_now(evaluation.inserted_at) %>
                                    </p>
                                  </div>
                                </div>

                                <div class="bg-gray-50 p-3 rounded-lg border border-gray-200">
                                  <p class="text-xs font-semibold text-gray-600 uppercase mb-1">Comments:</p>
                                  <p class="text-sm text-gray-800"><%= evaluation.comments %></p>
                                </div>

                                <div class="flex justify-end mt-3">
                                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{score_bg_color(evaluation.score)}"}>
                                    <%= score_label(evaluation.score) %>
                                  </span>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <!-- Projects Tab -->
                  <%= if @profile_tab == "projects" do %>
                    <div class="bg-white shadow rounded-xl overflow-hidden">
                      <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-semibold text-gray-900">Projects</h3>
                      </div>
                      <div class="p-6">
                        <%= if @attachee_projects == [] do %>
                          <p class="text-sm text-gray-500">No projects found for this attachee.</p>
                        <% else %>
                          <div class="overflow-x-auto">
                            <table class="min-w-full text-sm">
                              <thead>
                                <tr class="text-left text-xs font-semibold text-gray-500 border-b">
                                  <th class="py-2 pr-4">Project</th>
                                  <th class="py-2 pr-4">Program</th>
                                </tr>
                              </thead>
                              <tbody>
                                <%= for project <- @attachee_projects do %>
                                  <tr class="border-b last:border-0">
                                    <td class="py-2 pr-4 font-medium text-gray-900"><%= project.name %></td>
                                    <td class="py-2 pr-4 text-gray-600">
                                      <%= if project.program, do: project.program.name, else: "N/A" %>
                                    </td>
                                  </tr>
                                <% end %>
                              </tbody>
                            </table>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <!-- Tasks & Scores Tab -->
                  <%= if @profile_tab == "tasks" do %>
                    <div class="bg-white shadow rounded-xl overflow-hidden">
                      <div class="px-6 py-4 border-b border-gray-200">
                        <h3 class="text-lg font-semibold text-gray-900">Tasks & Scores</h3>
                      </div>
                      <div class="p-6">
                        <%= if @attachee_tasks == [] do %>
                          <p class="text-sm text-gray-500">No tasks found for this attachee.</p>
                        <% else %>
                          <div class="overflow-x-auto">
                            <table class="min-w-full text-sm">
                              <thead>
                                <tr class="text-left text-xs font-semibold text-gray-500 border-b">
                                  <th class="py-2 pr-4">Task</th>
                                  <th class="py-2 pr-4">Status</th>
                                  <th class="py-2 pr-4">Latest Score</th>
                                  <th class="py-2 pr-4">Performance</th>
                                </tr>
                              </thead>
                              <tbody>
                                <%= for task <- @attachee_tasks do %>
                                  <% score_info = Map.get(@task_scores, task.id) %>
                                  <tr class="border-b last:border-0">
                                    <td class="py-2 pr-4 font-medium text-gray-900">
                                      <%= Map.get(task, :title) || Map.get(task, :name) || "Task ##{task.id}" %>
                                    </td>
                                    <td class="py-2 pr-4">
                                      <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{status_color(Map.get(task, :status, "pending"))}"}>
                                        <%= String.capitalize(Map.get(task, :status, "pending")) %>
                                      </span>
                                    </td>
                                    <td class="py-2 pr-4">
                                      <%= if score_info do %>
                                        <span class="font-semibold"><%= score_info.score %>/100</span>
                                      <% else %>
                                        <span class="text-gray-400 text-xs">Not evaluated</span>
                                      <% end %>
                                    </td>
                                    <td class="py-2 pr-4">
                                      <%= if score_info do %>
                                        <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{score_bg_color(score_info.score)}"}>
                                          <%= score_info.label %>
                                        </span>
                                      <% else %>
                                        —
                                      <% end %>
                                    </td>
                                  </tr>
                                <% end %>
                              </tbody>
                            </table>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <!-- No Selection -->
                <div class="lg:col-span-2">
                  <div class="bg-white shadow rounded-xl h-full">
                    <div class="h-full flex items-center justify-center p-12">
                      <div class="text-center">
                        <svg class="w-24 h-24 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                        <h3 class="text-xl font-bold text-gray-900 mb-2">Select an Attachee to Evaluate</h3>
                        <p class="text-gray-500">Click on any attachee from the list to view their profile and evaluation history</p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>

      <!-- Evaluation Modal -->
      <.live_component
        :if={@show_evaluation_form}
        module={EvaluationForm}
        id="eval-form"
        attachee={@selected_attachee}
        current_user={@current_user}
        attachee_tasks={@attachee_tasks}
        evaluation_criteria={@evaluation_criteria}
        max_criteria={7}
      />
    </div>
    """
  end
end
