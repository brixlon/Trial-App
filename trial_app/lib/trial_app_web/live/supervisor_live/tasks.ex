defmodule TrialAppWeb.SupervisorLive.Tasks do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    active_role = Accounts.get_active_role(current_user)

    # FIXED: Load tasks based on role
    {all_tasks, projects} = case active_role do
      "admin" ->
        # Admin sees ALL tasks and ALL projects
        {Eams.list_tasks(%{preloads: [:project, assignee: :user]}),
         Eams.list_projects(%{preloads: [:program, :department, :organization]})}

      _ ->
        # Supervisor sees only their tasks and projects
        {Eams.list_tasks_for_supervisor(current_user.id),
         Eams.list_projects_for_supervisor(current_user.id)}
    end

    # Group tasks by status
    pending_approval = Enum.filter(all_tasks, &(&1.status == "submitted"))
    overdue_tasks = get_overdue_tasks(all_tasks)

    # Group by project
    tasks_by_project = Enum.group_by(all_tasks, & &1.project_id)

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:active_role, active_role)
     |> assign(:all_tasks, all_tasks)
     |> assign(:projects, projects)
     |> assign(:pending_approval, pending_approval)
     |> assign(:overdue_tasks, overdue_tasks)
     |> assign(:tasks_by_project, tasks_by_project)
     |> assign(:selected_tab, "all")
     |> assign(:selected_task, nil)
     |> assign(:show_task_modal, false)
     |> assign(:page_title, "Tasks Management")}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  def handle_event("view_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id, %{preloads: [:project, assignee: :user]})

    {:noreply,
     socket
     |> assign(:selected_task, task)
     |> assign(:show_task_modal, true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_task, nil)
     |> assign(:show_task_modal, false)}
  end

  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("approve_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id)

    case Eams.update_task(task, %{status: "completed"}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task approved successfully!")
         |> assign(:show_task_modal, false)
         |> reload_tasks()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve task")}
    end
  end

  def handle_event("reject_task", %{"id" => id, "reason" => reason}, socket) do
    task = Eams.get_task!(id)

    case Eams.update_task(task, %{status: "rejected", reject_reason: reason}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task rejected")
         |> assign(:show_task_modal, false)
         |> reload_tasks()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject task")}
    end
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
       #  |> put_flash(:info, "Switched to #{new_role} role")
         |> push_navigate(to: redirect_path)}

      {:error, :unauthorized_role} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to switch to that role")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end

  # FIXED: Reload tasks based on current role
  defp reload_tasks(socket) do
    current_user = socket.assigns.current_user
    active_role = socket.assigns.active_role

    all_tasks = case active_role do
      "admin" ->
        Eams.list_tasks(%{preloads: [:project, assignee: :user]})
      _ ->
        Eams.list_tasks_for_supervisor(current_user.id)
    end

    pending_approval = Enum.filter(all_tasks, &(&1.status == "submitted"))
    overdue_tasks = get_overdue_tasks(all_tasks)
    tasks_by_project = Enum.group_by(all_tasks, & &1.project_id)

    socket
    |> assign(:all_tasks, all_tasks)
    |> assign(:pending_approval, pending_approval)
    |> assign(:overdue_tasks, overdue_tasks)
    |> assign(:tasks_by_project, tasks_by_project)
  end

  defp get_overdue_tasks(tasks) do
    today = Date.utc_today()

    Enum.filter(tasks, fn task ->
      task.due_on && Date.compare(task.due_on, today) == :lt && task.status not in ["completed", "submitted"]
    end)
  end

  defp is_overdue?(task) do
    task.due_on && Date.compare(task.due_on, Date.utc_today()) == :lt && task.status not in ["completed"]
  end

  defp days_overdue(task) do
    if task.due_on do
      Date.diff(Date.utc_today(), task.due_on)
    else
      0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="lg:ml-64 p-8">
        <div class="max-w-7xl mx-auto">
          <!-- Header -->
          <div class="flex justify-between items-center mb-8">
            <div>
              <h1 class="text-3xl font-bold">Tasks Management</h1>
              <p class="text-base-content/70">Monitor and manage all tasks across projects</p>
            </div>
            <.link navigate={~p"/supervisor/dashboard"} class="btn btn-outline">
              ← Back to Dashboard
            </.link>
          </div>

          <!-- Stats Cards -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Total Tasks</p>
                <p class="text-3xl font-bold text-primary"><%= length(@all_tasks) %></p>
              </div>
            </div>

            <div class="card bg-gradient-to-br from-yellow-500 to-orange-500 text-white shadow-xl animate-pulse">
              <div class="card-body">
                <p class="text-sm opacity-90">Pending Approval</p>
                <p class="text-3xl font-bold"><%= length(@pending_approval) %></p>
              </div>
            </div>

            <div class={["card bg-gradient-to-br from-red-500 to-red-700 text-white shadow-xl", length(@overdue_tasks) > 0 && "animate-pulse"]}>
              <div class="card-body">
                <p class="text-sm opacity-90">Overdue Tasks</p>
                <p class="text-3xl font-bold"><%= length(@overdue_tasks) %></p>
              </div>
            </div>

            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <p class="text-sm text-base-content/70">Completed</p>
                <p class="text-3xl font-bold text-success">
                  <%= Enum.count(@all_tasks, &(&1.status == "completed")) %>
                </p>
              </div>
            </div>
          </div>

          <!-- Tabs -->
          <div class="tabs tabs-boxed mb-6 bg-base-100 p-2">
            <button
              phx-click="select_tab"
              phx-value-tab="all"
              class={["tab tab-lg", @selected_tab == "all" && "tab-active"]}
            >
              All Tasks (<%= length(@all_tasks) %>)
            </button>
            <button
              phx-click="select_tab"
              phx-value-tab="pending"
              class={["tab tab-lg", @selected_tab == "pending" && "tab-active"]}
            >
              Pending Approval (<%= length(@pending_approval) %>)
            </button>
            <button
              phx-click="select_tab"
              phx-value-tab="overdue"
              class={["tab tab-lg", @selected_tab == "overdue" && "tab-active"]}
            >
              Overdue (<%= length(@overdue_tasks) %>)
            </button>
            <button
              phx-click="select_tab"
              phx-value-tab="by_project"
              class={["tab tab-lg", @selected_tab == "by_project" && "tab-active"]}
            >
              By Project
            </button>
          </div>

          <!-- Tab Content -->
          <%= case @selected_tab do %>
            <%# ALL TASKS TAB %>
            <% "all" -> %>
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <h2 class="card-title">All Tasks</h2>
                  <%= if @all_tasks == [] do %>
                    <div class="text-center py-12">
                      <p class="text-base-content/50">No tasks yet</p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="table table-zebra">
                        <thead>
                          <tr>
                            <th>Task</th>
                            <th>Attachee</th>
                            <th>Project</th>
                            <th>Status</th>
                            <th>Due Date</th>
                            <th>Actions</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for task <- @all_tasks do %>
                            <tr class={if is_overdue?(task), do: "bg-red-50 animate-pulse"}>
                              <td>
                                <div class="font-bold"><%= task.title %></div>
                                <div class="text-sm opacity-70"><%= task.description %></div>
                              </td>
                              <td>
                                <div class="flex items-center gap-2">
                                  <div class="avatar placeholder">
                                    <div class="bg-neutral text-neutral-content rounded-full w-8">
                                      <span class="text-xs">
                                        <%= String.first(task.assignee.user.username || task.assignee.user.email) |> String.upcase() %>
                                      </span>
                                    </div>
                                  </div>
                                  <span><%= task.assignee.user.username || task.assignee.user.email %></span>
                                </div>
                              </td>
                              <td><%= task.project.name %></td>
                              <td>
                                <span class={"badge #{status_badge(task.status)}"}>
                                  <%= format_status(task.status) %>
                                </span>
                              </td>
                              <td>
                                <%= if task.due_on do %>
                                  <div class={if is_overdue?(task), do: "text-red-600 font-bold animate-pulse", else: ""}>
                                    <%= Calendar.strftime(task.due_on, "%b %d, %Y") %>
                                    <%= if is_overdue?(task) do %>
                                      <div class="text-xs">Overdue by <%= days_overdue(task) %> days</div>
                                    <% end %>
                                  </div>
                                <% else %>
                                  <span class="text-base-content/50">No due date</span>
                                <% end %>
                              </td>
                              <td>
                                <button
                                  phx-click="view_task"
                                  phx-value-id={task.id}
                                  class="btn btn-sm btn-primary"
                                >
                                  View
                                </button>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                </div>
              </div>

            <%# PENDING APPROVAL TAB %>
            <% "pending" -> %>
              <div class="card bg-gradient-to-br from-yellow-50 to-orange-50 shadow-xl border-2 border-yellow-400">
                <div class="card-body">
                  <h2 class="card-title text-yellow-800">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                    Tasks Awaiting Your Approval
                  </h2>
                  <%= if @pending_approval == [] do %>
                    <div class="text-center py-12">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-green-500 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <p class="text-base-content/50 text-lg">All caught up! No tasks pending approval.</p>
                    </div>
                  <% else %>
                    <div class="space-y-4">
                      <%= for task <- @pending_approval do %>
                        <div class="card bg-white shadow-md border-l-4 border-yellow-500">
                          <div class="card-body">
                            <div class="flex justify-between items-start">
                              <div class="flex-1">
                                <h3 class="font-bold text-lg"><%= task.title %></h3>
                                <p class="text-sm text-base-content/70 mb-2"><%= task.description %></p>
                                <div class="flex gap-4 text-sm">
                                  <span>
                                    <strong>Attachee:</strong> <%= task.assignee.user.username || task.assignee.user.email %>
                                  </span>
                                  <span>
                                    <strong>Project:</strong> <%= task.project.name %>
                                  </span>
                                  <%= if task.due_on do %>
                                    <span>
                                      <strong>Due:</strong> <%= Calendar.strftime(task.due_on, "%b %d, %Y") %>
                                    </span>
                                  <% end %>
                                </div>
                              </div>
                              <button
                                phx-click="view_task"
                                phx-value-id={task.id}
                                class="btn btn-warning btn-sm"
                              >
                                Review & Approve
                              </button>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

            <%# OVERDUE TAB %>
            <% "overdue" -> %>
              <div class="card bg-gradient-to-br from-red-50 to-red-100 shadow-xl border-2 border-red-500">
                <div class="card-body">
                  <h2 class="card-title text-red-800">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Overdue Tasks - Immediate Attention Required
                  </h2>
                  <%= if @overdue_tasks == [] do %>
                    <div class="text-center py-12">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-green-500 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <p class="text-base-content/50 text-lg">Great! No overdue tasks.</p>
                    </div>
                  <% else %>
                    <div class="space-y-4">
                      <%= for task <- Enum.sort_by(@overdue_tasks, &days_overdue/1, :desc) do %>
                        <div class="card bg-white shadow-md border-l-4 border-red-600 animate-pulse">
                          <div class="card-body">
                            <div class="flex justify-between items-start">
                              <div class="flex-1">
                                <div class="flex items-center gap-2 mb-2">
                                  <span class="badge badge-error badge-lg">
                                    <%= days_overdue(task) %> days overdue
                                  </span>
                                  <h3 class="font-bold text-lg"><%= task.title %></h3>
                                </div>
                                <p class="text-sm text-base-content/70 mb-2"><%= task.description %></p>
                                <div class="flex gap-4 text-sm">
                                  <span>
                                    <strong>Attachee:</strong> <%= task.assignee.user.username || task.assignee.user.email %>
                                  </span>
                                  <span>
                                    <strong>Project:</strong> <%= task.project.name %>
                                  </span>
                                  <span class="text-red-600 font-bold">
                                    <strong>Was due:</strong> <%= Calendar.strftime(task.due_on, "%b %d, %Y") %>
                                  </span>
                                </div>
                              </div>
                              <button
                                phx-click="view_task"
                                phx-value-id={task.id}
                                class="btn btn-error btn-sm"
                              >
                                View Details
                              </button>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

            <%# BY PROJECT TAB %>
            <% "by_project" -> %>
              <div class="space-y-6">
                <%= for project <- @projects do %>
                  <% project_tasks = Map.get(@tasks_by_project, project.id, []) %>
                  <%= if project_tasks != [] do %>
                    <div class="card bg-base-100 shadow-xl">
                      <div class="card-body">
                        <div class="flex justify-between items-center mb-4">
                          <div>
                            <h2 class="card-title text-xl"><%= project.name %></h2>
                            <p class="text-sm text-base-content/70"><%= project.description || "No description" %></p>
                          </div>
                          <div class="stats shadow">
                            <div class="stat place-items-center p-4">
                              <div class="stat-title text-xs">Total</div>
                              <div class="stat-value text-2xl text-primary"><%= length(project_tasks) %></div>
                            </div>
                            <div class="stat place-items-center p-4">
                              <div class="stat-title text-xs">Pending</div>
                              <div class="stat-value text-2xl text-warning">
                                <%= Enum.count(project_tasks, &(&1.status == "submitted")) %>
                              </div>
                            </div>
                            <div class="stat place-items-center p-4">
                              <div class="stat-title text-xs">Overdue</div>
                              <div class="stat-value text-2xl text-error">
                                <%= Enum.count(project_tasks, &is_overdue?/1) %>
                              </div>
                            </div>
                          </div>
                        </div>

                        <div class="overflow-x-auto">
                          <table class="table table-sm">
                            <thead>
                              <tr>
                                <th>Task</th>
                                <th>Attachee</th>
                                <th>Status</th>
                                <th>Due Date</th>
                                <th>Actions</th>
                              </tr>
                            </thead>
                            <tbody>
                              <%= for task <- project_tasks do %>
                                <tr class={if is_overdue?(task), do: "bg-red-50"}>
                                  <td>
                                    <div class="font-bold text-sm"><%= task.title %></div>
                                  </td>
                                  <td class="text-sm"><%= task.assignee.user.username || task.assignee.user.email %></td>
                                  <td>
                                    <span class={"badge badge-sm #{status_badge(task.status)}"}>
                                      <%= format_status(task.status) %>
                                    </span>
                                  </td>
                                  <td class="text-sm">
                                    <%= if task.due_on do %>
                                      <span class={if is_overdue?(task), do: "text-red-600 font-bold"}>
                                        <%= Calendar.strftime(task.due_on, "%b %d") %>
                                      </span>
                                    <% else %>
                                      -
                                    <% end %>
                                  </td>
                                  <td>
                                    <button
                                      phx-click="view_task"
                                      phx-value-id={task.id}
                                      class="btn btn-xs btn-primary"
                                    >
                                      View
                                    </button>
                                  </td>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
          <% end %>
        </div>
      </div>

      <%# TASK DETAIL MODAL %>
      <%= if @show_task_modal && @selected_task do %>
        <div class="modal modal-open" phx-click="close_modal">
          <div class="modal-box max-w-2xl" phx-click="stop_propagation">
            <h3 class="font-bold text-lg mb-4"><%= @selected_task.title %></h3>

            <div class="space-y-4">
              <div>
                <strong>Description:</strong>
                <p class="text-sm text-base-content/70"><%= @selected_task.description %></p>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <div>
                  <strong>Attachee:</strong>
                  <p><%= @selected_task.assignee.user.username || @selected_task.assignee.user.email %></p>
                </div>
                <div>
                  <strong>Project:</strong>
                  <p><%= @selected_task.project.name %></p>
                </div>
                <div>
                  <strong>Status:</strong>
                  <span class={"badge #{status_badge(@selected_task.status)}"}>
                    <%= format_status(@selected_task.status) %>
                  </span>
                </div>
                <div>
                  <strong>Due Date:</strong>
                  <p>
                    <%= if @selected_task.due_on do %>
                      <%= Calendar.strftime(@selected_task.due_on, "%b %d, %Y") %>
                    <% else %>
                      No due date
                    <% end %>
                  </p>
                </div>
              </div>

              <%= if @selected_task.submission_comment do %>
                <div class="alert alert-info">
                  <div>
                    <strong>Submission Comment:</strong>
                    <p class="mt-1"><%= @selected_task.submission_comment %></p>
                  </div>
                </div>
              <% end %>

              <%= if @selected_task.submission_links && @selected_task.submission_links != [] do %>
                <div>
                  <strong>Submitted Links:</strong>
                  <div class="space-y-2 mt-2">
                    <%= for link <- @selected_task.submission_links do %>
                      <div class="flex items-center gap-2 p-2 bg-base-200 rounded">
                        <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                        </svg>
                        <a href={link} target="_blank" class="text-blue-600 hover:underline text-sm flex-1 truncate">
                          <%= link %>
                        </a>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <%= if @selected_task.submission_files && @selected_task.submission_files != [] do %>
                <div>
                  <strong>Submitted Files:</strong>
                  <div class="space-y-2 mt-2">
                    <%= for file <- @selected_task.submission_files do %>
                      <div class="flex items-center justify-between p-3 bg-base-200 rounded">
                        <div class="flex items-center gap-2 flex-1">
                          <svg class="w-5 h-5 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                          <span class="text-sm font-medium truncate"><%= Path.basename(file) %></span>
                        </div>
                        <a href={file} target="_blank" download class="btn btn-xs btn-primary">
                          Download
                        </a>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <%= if @selected_task.status == "submitted" do %>
                <div class="divider">Approve or Reject</div>

                <form phx-submit="reject_task" phx-value-id={@selected_task.id}>
                  <textarea
                    name="reason"
                    class="textarea textarea-bordered w-full mb-2"
                    placeholder="Rejection reason (optional)"
                    rows="3"
                  ></textarea>

                  <div class="flex gap-2 justify-end">
                    <button
                      type="button"
                      phx-click="close_modal"
                      class="btn btn-ghost"
                    >
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-error">
                      Reject
                    </button>
                    <button
                      type="button"
                      phx-click="approve_task"
                      phx-value-id={@selected_task.id}
                      class="btn btn-success"
                    >
                      Approve Task
                    </button>
                  </div>
                </form>
              <% else %>
                <div class="modal-action">
                  <button phx-click="close_modal" class="btn">Close</button>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_badge("pending"), do: "badge-warning"
  defp status_badge("in_progress"), do: "badge-info"
  defp status_badge("submitted"), do: "badge-primary"
  defp status_badge("completed"), do: "badge-success"
  defp status_badge("rejected"), do: "badge-error"
  defp status_badge(_), do: "badge-ghost"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
