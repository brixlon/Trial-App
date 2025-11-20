defmodule TrialAppWeb.SupervisorLive.Tasks do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams}
  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    active_role = Accounts.get_active_role(current_user)
    {all_tasks, projects} = case active_role do
      "admin" ->
        {Eams.list_tasks(%{preloads: [:project, assignee: :user]}),
         Eams.list_projects(%{preloads: [:program, :department, :organization]})}
      _ ->
        {Eams.list_tasks_for_supervisor(current_user.id),
         Eams.list_projects_for_supervisor(current_user.id)}
    end
    pending_approval = Enum.filter(all_tasks, &(&1.status == "submitted"))
    overdue_tasks = get_overdue_tasks(all_tasks)
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
         |> push_navigate(to: redirect_path)}
      {:error, :unauthorized_role} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to switch to that role")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end
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
      <div class="lg:ml-64 p-8">
        <div class="max-w-7xl mx-auto">
          <!-- Header -->
          <div class="flex justify-between items-center mb-8">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Tasks Management</h1>
              <p class="text-gray-600 mt-1">Monitor and manage all tasks across projects</p>
            </div>
            <.link navigate={~p"/supervisor/dashboard"} class="px-6 py-2.5 border border-purple-600 text-purple-600 rounded-lg hover:bg-purple-50 transition-colors font-medium">
              ← Back to Dashboard
            </.link>
          </div>
          <!-- Stats Cards -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="bg-white rounded-xl shadow-md p-6">
              <p class="text-sm text-gray-600 mb-2">Total Tasks</p>
              <p class="text-4xl font-bold text-purple-600"><%= length(@all_tasks) %></p>
            </div>
            <div class="bg-gradient-to-br from-yellow-500 to-orange-500 text-white rounded-xl shadow-md p-6 animate-pulse">
              <p class="text-sm opacity-90 mb-2">Pending Approval</p>
              <p class="text-4xl font-bold"><%= length(@pending_approval) %></p>
            </div>
            <div class={["bg-gradient-to-br from-red-500 to-red-700 text-white rounded-xl shadow-md p-6", length(@overdue_tasks) > 0 && "animate-pulse"]}>
              <p class="text-sm opacity-90 mb-2">Overdue Tasks</p>
              <p class="text-4xl font-bold"><%= length(@overdue_tasks) %></p>
            </div>
            <div class="bg-white rounded-xl shadow-md p-6">
              <p class="text-sm text-gray-600 mb-2">Completed</p>
              <p class="text-4xl font-bold text-green-600">
                <%= Enum.count(@all_tasks, &(&1.status == "completed")) %>
              </p>
            </div>
          </div>
          <!-- Tabs -->
          <div class="bg-white rounded-xl shadow-md p-2 mb-6 inline-flex gap-1">
            <button
              phx-click="select_tab"
              phx-value-tab="all"
              class={["px-6 py-2.5 rounded-lg font-medium transition-colors",
                      @selected_tab == "all" && "bg-purple-600 text-white" || "text-gray-600 hover:bg-gray-100"]}
            >
              All Tasks (<%= length(@all_tasks) %>)
            </button>
            <button
              phx-click="select_tab"
              phx-value-tab="pending"
              class={["px-6 py-2.5 rounded-lg font-medium transition-colors",
                      @selected_tab == "pending" && "bg-purple-600 text-white" || "text-gray-600 hover:bg-gray-100"]}
            >
              Pending Approval (<%= length(@pending_approval) %>)
            </button>
            <button
              phx-click="select_tab"
              phx-value-tab="overdue"
              class={["px-6 py-2.5 rounded-lg font-medium transition-colors",
                      @selected_tab == "overdue" && "bg-purple-600 text-white" || "text-gray-600 hover:bg-gray-100"]}
            >
              Overdue (<%= length(@overdue_tasks) %>)
            </button>
            <button
              phx-click="select_tab"
              phx-value-tab="by_project"
              class={["px-6 py-2.5 rounded-lg font-medium transition-colors",
                      @selected_tab == "by_project" && "bg-purple-600 text-white" || "text-gray-600 hover:bg-gray-100"]}
            >
              By Project
            </button>
          </div>
          <!-- Tab Content -->
          <%= case @selected_tab do %>
            <%# ALL TASKS TAB %>
            <% "all" -> %>
              <div class="bg-white rounded-xl shadow-md overflow-hidden">
                <div class="p-6">
                  <h2 class="text-xl font-bold text-gray-900 mb-4">All Tasks</h2>
                  <%= if @all_tasks == [] do %>
                    <div class="text-center py-12">
                      <p class="text-gray-500">No tasks yet</p>
                    </div>
                  <% else %>
                    <div class="overflow-x-auto">
                      <table class="min-w-full divide-y divide-gray-200">
                        <thead class="bg-gray-50">
                          <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Task</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Attachee</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Project</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Due Date</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                          </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
                          <%= for task <- @all_tasks do %>
                            <tr class={["hover:bg-gray-50", is_overdue?(task) && "bg-red-50 animate-pulse"]}>
                              <td class="px-6 py-4">
                                <div class="font-semibold text-gray-900"><%= task.title %></div>
                                <div class="text-sm text-gray-500"><%= task.description %></div>
                              </td>
                              <td class="px-6 py-4">
                                <div class="flex items-center gap-2">
                                  <div class="w-8 h-8 rounded-full bg-purple-600 text-white flex items-center justify-center text-xs font-semibold">
                                    <%= String.first(task.assignee.user.username || task.assignee.user.email) |> String.upcase() %>
                                  </div>
                                  <span class="text-sm text-gray-900"><%= task.assignee.user.username || task.assignee.user.email %></span>
                                </div>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900"><%= task.project.name %></td>
                              <td class="px-6 py-4">
                                <span class={"inline-flex px-3 py-1 text-xs font-semibold rounded-full #{status_color(task.status)}"}>
                                  <%= format_status(task.status) %>
                                </span>
                              </td>
                              <td class="px-6 py-4 text-sm">
                                <%= if task.due_on do %>
                                  <div class={is_overdue?(task) && "text-red-600 font-bold animate-pulse" || "text-gray-900"}>
                                    <%= Calendar.strftime(task.due_on, "%b %d, %Y") %>
                                    <%= if is_overdue?(task) do %>
                                      <div class="text-xs mt-1">Overdue by <%= days_overdue(task) %> days</div>
                                    <% end %>
                                  </div>
                                <% else %>
                                  <span class="text-gray-500">No due date</span>
                                <% end %>
                              </td>
                              <td class="px-6 py-4">
                                <button
                                  phx-click="view_task"
                                  phx-value-id={task.id}
                                  class="px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 transition-colors"
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
              <div class="bg-gradient-to-br from-yellow-50 to-orange-50 rounded-xl shadow-md border-2 border-yellow-400 overflow-hidden">
                <div class="p-6">
                  <h2 class="text-xl font-bold text-yellow-800 mb-4 flex items-center gap-2">
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
                      <p class="text-gray-600 text-lg">All caught up! No tasks pending approval.</p>
                    </div>
                  <% else %>
                    <div class="space-y-4">
                      <%= for task <- @pending_approval do %>
                        <div class="bg-white rounded-lg shadow-md border-l-4 border-yellow-500 overflow-hidden">
                          <div class="p-6">
                            <div class="flex justify-between items-start">
                              <div class="flex-1">
                                <h3 class="font-bold text-lg text-gray-900"><%= task.title %></h3>
                                <p class="text-sm text-gray-600 mb-3"><%= task.description %></p>
                                <div class="flex gap-6 text-sm text-gray-700">
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
                                class="px-4 py-2 bg-yellow-500 text-white text-sm font-medium rounded-lg hover:bg-yellow-600 transition-colors"
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
              <div class="bg-gradient-to-br from-red-50 to-red-100 rounded-xl shadow-md border-2 border-red-500 overflow-hidden">
                <div class="p-6">
                  <h2 class="text-xl font-bold text-red-800 mb-4 flex items-center gap-2">
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
                      <p class="text-gray-600 text-lg">Great! No overdue tasks.</p>
                    </div>
                  <% else %>
                    <div class="space-y-4">
                      <%= for task <- Enum.sort_by(@overdue_tasks, &days_overdue/1, :desc) do %>
                        <div class="bg-white rounded-lg shadow-md border-l-4 border-red-600 overflow-hidden animate-pulse">
                          <div class="p-6">
                            <div class="flex justify-between items-start">
                              <div class="flex-1">
                                <div class="flex items-center gap-3 mb-2">
                                  <span class="inline-flex px-3 py-1 text-xs font-bold bg-red-600 text-white rounded-full">
                                    <%= days_overdue(task) %> days overdue
                                  </span>
                                  <h3 class="font-bold text-lg text-gray-900"><%= task.title %></h3>
                                </div>
                                <p class="text-sm text-gray-600 mb-3"><%= task.description %></p>
                                <div class="flex gap-6 text-sm text-gray-700">
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
                                class="px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700 transition-colors"
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
                    <div class="bg-white rounded-xl shadow-md overflow-hidden">
                      <div class="p-6">
                        <div class="flex justify-between items-center mb-6">
                          <div>
                            <h2 class="text-xl font-bold text-gray-900"><%= project.name %></h2>
                            <p class="text-sm text-gray-600 mt-1"><%= project.description || "No description" %></p>
                          </div>
                          <div class="flex gap-4">
                            <div class="text-center px-6 py-3 bg-purple-50 rounded-lg">
                              <div class="text-xs text-gray-600 mb-1">Total</div>
                              <div class="text-2xl font-bold text-purple-600"><%= length(project_tasks) %></div>
                            </div>
                            <div class="text-center px-6 py-3 bg-yellow-50 rounded-lg">
                              <div class="text-xs text-gray-600 mb-1">Pending</div>
                              <div class="text-2xl font-bold text-yellow-600">
                                <%= Enum.count(project_tasks, &(&1.status == "submitted")) %>
                              </div>
                            </div>
                            <div class="text-center px-6 py-3 bg-red-50 rounded-lg">
                              <div class="text-xs text-gray-600 mb-1">Overdue</div>
                              <div class="text-2xl font-bold text-red-600">
                                <%= Enum.count(project_tasks, &is_overdue?/1) %>
                              </div>
                            </div>
                          </div>
                        </div>
                        <div class="overflow-x-auto">
                          <table class="min-w-full divide-y divide-gray-200">
                            <thead class="bg-gray-50">
                              <tr>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Task</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Attachee</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Due Date</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                              </tr>
                            </thead>
                            <tbody class="bg-white divide-y divide-gray-200">
                              <%= for task <- project_tasks do %>
                                <tr class={["hover:bg-gray-50", is_overdue?(task) && "bg-red-50"]}>
                                  <td class="px-6 py-4">
                                    <div class="font-semibold text-sm text-gray-900"><%= task.title %></div>
                                  </td>
                                  <td class="px-6 py-4 text-sm text-gray-900"><%= task.assignee.user.username || task.assignee.user.email %></td>
                                  <td class="px-6 py-4">
                                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{status_color(task.status)}"}>
                                      <%= format_status(task.status) %>
                                    </span>
                                  </td>
                                  <td class="px-6 py-4 text-sm">
                                    <%= if task.due_on do %>
                                      <span class={is_overdue?(task) && "text-red-600 font-bold" || "text-gray-900"}>
                                        <%= Calendar.strftime(task.due_on, "%b %d") %>
                                      </span>
                                    <% else %>
                                      <span class="text-gray-500">-</span>
                                    <% end %>
                                  </td>
                                  <td class="px-6 py-4">
                                    <button
                                      phx-click="view_task"
                                      phx-value-id={task.id}
                                      class="px-3 py-1.5 bg-purple-600 text-white text-xs font-medium rounded-lg hover:bg-purple-700 transition-colors"
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
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" phx-click="close_modal">
          <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto" phx-click="stop_propagation">
            <div class="p-6">
              <h3 class="text-2xl font-bold text-gray-900 mb-6"><%= @selected_task.title %></h3>
              <div class="space-y-6">
                <div>
                  <strong class="text-gray-700 block mb-2">Description:</strong>
                  <p class="text-sm text-gray-600"><%= @selected_task.description %></p>
                </div>
                <div class="grid grid-cols-2 gap-6">
                  <div>
                    <strong class="text-gray-700 block mb-2">Attachee:</strong>
                    <p class="text-gray-900"><%= @selected_task.assignee.user.username || @selected_task.assignee.user.email %></p>
                  </div>
                  <div>
                    <strong class="text-gray-700 block mb-2">Project:</strong>
                    <p class="text-gray-900"><%= @selected_task.project.name %></p>
                  </div>
                  <div>
                    <strong class="text-gray-700 block mb-2">Status:</strong>
                    <span class={"inline-flex px-3 py-1 text-xs font-semibold rounded-full #{status_color(@selected_task.status)}"}>
                      <%= format_status(@selected_task.status) %>
                    </span>
                  </div>
                  <div>
                    <strong class="text-gray-700 block mb-2">Due Date:</strong>
                    <p class="text-gray-900">
                      <%= if @selected_task.due_on do %>
                        <%= Calendar.strftime(@selected_task.due_on, "%b %d, %Y") %>
                      <% else %>
                        No due date
                      <% end %>
                    </p>
                  </div>
                </div>
                <%= if @selected_task.submission_comment do %>
                  <div class="bg-blue-50 rounded-lg p-4">
                    <strong class="text-blue-700 block mb-2">Submission Comment:</strong>
                    <p class="text-sm text-blue-600"><%= @selected_task.submission_comment %></p>
                  </div>
                <% end %>
                <%= if @selected_task.submission_links && @selected_task.submission_links != [] do %>
                  <div>
                    <strong class="text-gray-700 block mb-2">Submitted Links:</strong>
                    <div class="space-y-2 mt-2">
                      <%= for link <- @selected_task.submission_links do %>
                        <div class="flex items-center gap-2 p-3 bg-gray-100 rounded-lg">
                          <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                    <strong class="text-gray-700 block mb-2">Submitted Files:</strong>
                    <div class="space-y-2 mt-2">
                      <%= for file <- @selected_task.submission_files do %>
                        <div class="flex items-center justify-between p-3 bg-gray-100 rounded-lg">
                          <div class="flex items-center gap-2 flex-1">
                            <svg class="w-5 h-5 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                            </svg>
                            <span class="text-sm font-medium text-gray-900 truncate"><%= Path.basename(file) %></span>
                          </div>
                          <a href={file} target="_blank" download class="px-3 py-1.5 bg-purple-600 text-white text-xs font-medium rounded-lg hover:bg-purple-700 transition-colors">
                            Download
                          </a>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if @selected_task.status == "submitted" do %>
                  <div class="border-t border-gray-200 pt-6 mt-6">
                    <h4 class="text-lg font-bold text-gray-900 mb-4">Approve or Reject</h4>
                    <form phx-submit="reject_task" phx-value-id={@selected_task.id}>
                      <textarea
                        name="reason"
                        class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-purple-600 focus:ring-2 focus:ring-purple-200 text-sm text-gray-700 placeholder-gray-500"
                        placeholder="Rejection reason (optional)"
                        rows="3"
                      ></textarea>
                      <div class="flex gap-3 justify-end mt-4">
                        <button
                          type="button"
                          phx-click="close_modal"
                          class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-300 transition-colors"
                        >
                          Cancel
                        </button>
                        <button type="submit" class="px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700 transition-colors">
                          Reject
                        </button>
                        <button
                          type="button"
                          phx-click="approve_task"
                          phx-value-id={@selected_task.id}
                          class="px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-lg hover:bg-green-700 transition-colors"
                        >
                          Approve Task
                        </button>
                      </div>
                    </form>
                  </div>
                <% else %>
                  <div class="flex justify-end mt-6">
                    <button phx-click="close_modal" class="px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 transition-colors">
                      Close
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("in_progress"), do: "bg-blue-100 text-blue-800"
  defp status_color("submitted"), do: "bg-purple-100 text-purple-800"
  defp status_color("completed"), do: "bg-green-100 text-green-800"
  defp status_color("rejected"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
