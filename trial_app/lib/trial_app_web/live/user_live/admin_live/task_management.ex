defmodule TrialAppWeb.AdminLive.TaskManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialApp.Repo

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:tasks, load_tasks())
     |> assign(:show_form, false)
     |> assign(:projects, Eams.list_projects())
     |> assign(:attachees, Eams.list_attachees())
     |> assign(:form_data, %{
       "title" => "",
       "description" => "",
       "status" => "pending",
       "due_on" => "",
       "project_id" => "",
       "assignee_id" => ""
     })
     |> assign(:errors, %{})
     |> assign(:selected_task, nil)
     |> assign(:filter_status, "all")}
  end

  defp load_tasks do
    Eams.list_tasks()
    |> Repo.preload([:project, assignee: [:user]])
  end

  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />
    <div class="ml-64 p-8">
      <div class="mb-6">
        <h1 class="text-3xl font-bold text-gray-900">Task Management</h1>
        <p class="text-gray-600 mt-1">Create, assign, and track tasks for your projects</p>
      </div>

      <!-- Action Bar -->
      <div class="flex justify-between items-center mb-6">
        <div class="flex gap-2">
          <button
            phx-click="filter"
            phx-value-status="all"
            class={"px-4 py-2 rounded-lg #{if @filter_status == "all", do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 border"}"}
          >
            All Tasks
          </button>
          <button
            phx-click="filter"
            phx-value-status="pending"
            class={"px-4 py-2 rounded-lg #{if @filter_status == "pending", do: "bg-yellow-600 text-white", else: "bg-white text-gray-700 border"}"}
          >
            Pending
          </button>
          <button
            phx-click="filter"
            phx-value-status="in_progress"
            class={"px-4 py-2 rounded-lg #{if @filter_status == "in_progress", do: "bg-blue-600 text-white", else: "bg-white text-gray-700 border"}"}
          >
            In Progress
          </button>
          <button
            phx-click="filter"
            phx-value-status="completed"
            class={"px-4 py-2 rounded-lg #{if @filter_status == "completed", do: "bg-green-600 text-white", else: "bg-white text-gray-700 border"}"}
          >
            Completed
          </button>
        </div>
        <button phx-click="new" class="px-6 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 transition font-semibold">
          + New Task
        </button>
      </div>

      <!-- Tasks Grid -->
      <div class="bg-white rounded-xl border shadow-sm">
        <%= if filtered_tasks(@tasks, @filter_status) == [] do %>
          <div class="p-12 text-center">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No tasks</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by creating a new task.</p>
            <div class="mt-6">
              <button phx-click="new" class="px-4 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700">
                + New Task
              </button>
            </div>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50 border-b">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Task</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Project</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Assigned To</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Due Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for task <- filtered_tasks(@tasks, @filter_status) do %>
                  <tr class="hover:bg-gray-50 transition">
                    <td class="px-6 py-4">
                      <div class="flex flex-col">
                        <div class="text-sm font-semibold text-gray-900"><%= task.title %></div>
                        <%= if task.description && task.description != "" do %>
                          <div class="text-sm text-gray-600 mt-1 line-clamp-2"><%= task.description %></div>
                        <% end %>
                      </div>
                    </td>
                    <td class="px-6 py-4">
                      <div class="text-sm text-gray-900">
                        <%= if task.project do %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                            <%= task.project.name %>
                          </span>
                        <% else %>
                          <span class="text-gray-400">No project</span>
                        <% end %>
                      </div>
                    </td>
                    <td class="px-6 py-4">
                      <%= if task.assignee do %>
                        <div class="flex items-center">
                          <div class="flex-shrink-0 h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold text-sm">
                            <%= get_initials(task.assignee) %>
                          </div>
                          <div class="ml-3">
                            <div class="text-sm font-medium text-gray-900"><%= get_attachee_name(task.assignee) %></div>
                            <%= if task.assignee.user do %>
                              <div class="text-xs text-gray-500"><%= task.assignee.user.email %></div>
                            <% end %>
                          </div>
                        </div>
                      <% else %>
                        <span class="text-sm text-gray-400">Unassigned</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= if task.due_on do %>
                        <div class="text-sm text-gray-900"><%= format_date(task.due_on) %></div>
                        <div class={"text-xs #{due_date_color(task.due_on)}"}>
                          <%= relative_date(task.due_on) %>
                        </div>
                      <% else %>
                        <span class="text-sm text-gray-400">No due date</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={status_badge_class(task.status)}>
                        <%= format_status(task.status) %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                      <div class="flex gap-2">
                        <button
                          phx-click="view"
                          phx-value-id={task.id}
                          class="text-indigo-600 hover:text-indigo-900 font-medium"
                        >
                          View
                        </button>
                        <button
                          phx-click="edit"
                          phx-value-id={task.id}
                          class="text-blue-600 hover:text-blue-900 font-medium"
                        >
                          Edit
                        </button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <!-- Task Form Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-xl w-full max-w-2xl p-6 max-h-[90vh] overflow-y-auto">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-900">Create New Task</h2>
              <button phx-click="close" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <.form for={to_form(@form_data, as: :task)} id="task-form" phx-submit="save" phx-change="update">
              <div class="space-y-5">
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">Task Title *</label>
                  <input
                    name="title"
                    value={@form_data["title"]}
                    class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    placeholder="Enter task title"
                    required
                  />
                  <%= if @errors[:title] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@errors[:title], 0) %></p>
                  <% end %>
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">Project *</label>
                    <select name="project_id" class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500" required>
                      <option value="">Select a project</option>
                      <%= for p <- @projects do %>
                        <option value={p.id} selected={to_string(p.id) == @form_data["project_id"]}>
                          <%= p.name %>
                        </option>
                      <% end %>
                    </select>
                    <%= if @errors[:project_id] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(@errors[:project_id], 0) %></p>
                    <% end %>
                  </div>

                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">Assign to Attachee *</label>
                    <select name="assignee_id" class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500" required>
                      <option value="">Select an attachee</option>
                      <%= for a <- @attachees do %>
                        <option value={a.id} selected={to_string(a.id) == @form_data["assignee_id"]}>
                          <%= get_attachee_name(a) %>
                        </option>
                      <% end %>
                    </select>
                    <%= if @errors[:assignee_id] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(@errors[:assignee_id], 0) %></p>
                    <% end %>
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">Due Date</label>
                    <input
                      type="date"
                      name="due_on"
                      value={@form_data["due_on"]}
                      class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500"
                    />
                    <%= if @errors[:due_on] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(@errors[:due_on], 0) %></p>
                    <% end %>
                  </div>

                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">Status</label>
                    <select name="status" class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500">
                      <%= for s <- ["pending", "in_progress", "blocked", "completed", "cancelled"] do %>
                        <option value={s} selected={s == @form_data["status"]}>
                          <%= format_status(s) %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">Description</label>
                  <textarea
                    name="description"
                    class="w-full border border-gray-300 rounded-lg p-3 focus:ring-2 focus:ring-indigo-500"
                    rows="4"
                    placeholder="Add task description, requirements, or notes..."
                  ><%= @form_data["description"] %></textarea>
                </div>
              </div>

              <div class="flex justify-end gap-3 mt-8 pt-6 border-t">
                <button type="button" phx-click="close" class="px-6 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 font-medium transition">
                  Cancel
                </button>
                <button type="submit" class="px-6 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 font-semibold transition">
                  Create Task
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Task Detail Modal -->
      <%= if @selected_task do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-xl w-full max-w-2xl p-6 max-h-[90vh] overflow-y-auto">
            <div class="flex justify-between items-start mb-6">
              <div class="flex-1">
                <h2 class="text-2xl font-bold text-gray-900 mb-2"><%= @selected_task.title %></h2>
                <span class={status_badge_class(@selected_task.status)}>
                  <%= format_status(@selected_task.status) %>
                </span>
              </div>
              <button phx-click="close_detail" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div class="space-y-6">
              <%= if @selected_task.description && @selected_task.description != "" do %>
                <div>
                  <h3 class="text-sm font-semibold text-gray-700 mb-2">Description</h3>
                  <p class="text-gray-600"><%= @selected_task.description %></p>
                </div>
              <% end %>

              <div class="grid grid-cols-2 gap-6">
                <div>
                  <h3 class="text-sm font-semibold text-gray-700 mb-2">Project</h3>
                  <%= if @selected_task.project do %>
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
                      <%= @selected_task.project.name %>
                    </span>
                  <% else %>
                    <span class="text-gray-400">No project</span>
                  <% end %>
                </div>

                <div>
                  <h3 class="text-sm font-semibold text-gray-700 mb-2">Due Date</h3>
                  <%= if @selected_task.due_on do %>
                    <p class="text-gray-900"><%= format_date(@selected_task.due_on) %></p>
                    <p class={"text-sm #{due_date_color(@selected_task.due_on)}"}><%= relative_date(@selected_task.due_on) %></p>
                  <% else %>
                    <span class="text-gray-400">No due date</span>
                  <% end %>
                </div>
              </div>

              <div>
                <h3 class="text-sm font-semibold text-gray-700 mb-3">Assigned To</h3>
                <%= if @selected_task.assignee do %>
                  <div class="flex items-center p-4 bg-gray-50 rounded-lg">
                    <div class="flex-shrink-0 h-12 w-12 rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold text-lg">
                      <%= get_initials(@selected_task.assignee) %>
                    </div>
                    <div class="ml-4">
                      <div class="text-base font-semibold text-gray-900"><%= get_attachee_name(@selected_task.assignee) %></div>
                      <%= if @selected_task.assignee.user do %>
                        <div class="text-sm text-gray-600"><%= @selected_task.assignee.user.email %></div>
                      <% end %>
                      <%= if @selected_task.assignee.position do %>
                        <div class="text-xs text-gray-500 mt-1"><%= @selected_task.assignee.position %></div>
                      <% end %>
                    </div>
                  </div>
                <% else %>
                  <span class="text-gray-400">Unassigned</span>
                <% end %>
              </div>
            </div>

            <div class="flex justify-end gap-3 mt-8 pt-6 border-t">
              <button phx-click="close_detail" class="px-6 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 font-medium">
                Close
              </button>
              <button phx-click="edit" phx-value-id={@selected_task.id} class="px-6 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 font-semibold">
                Edit Task
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, show_form: true, selected_task: nil)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, show_form: false, errors: %{})}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, selected_task: nil)}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, filter_status: status)}
  end

  def handle_event("view", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == String.to_integer(id)))
    {:noreply, assign(socket, selected_task: task)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == String.to_integer(id)))

    form_data = %{
      "title" => task.title,
      "description" => task.description || "",
      "status" => task.status,
      "due_on" => if(task.due_on, do: Date.to_string(task.due_on), else: ""),
      "project_id" => if(task.project_id, do: to_string(task.project_id), else: ""),
      "assignee_id" => if(task.assignee_id, do: to_string(task.assignee_id), else: "")
    }

    {:noreply, assign(socket, show_form: true, selected_task: nil, form_data: form_data)}
  end

  def handle_event("update", %{"task" => params}, socket) do
    socket = assign(socket, form_data: Map.merge(socket.assigns.form_data, params))

    socket =
      case Map.get(params, "project_id") do
        nil ->
          socket

        "" ->
          socket

        proj_id_str ->
          project = Eams.get_project!(String.to_integer(proj_id_str))
          attachees = Eams.list_attachees_by_program(project.program_id, %{preloads: [:user]})
          assign(socket, attachees: attachees)
      end

    {:noreply, socket}
  end

  def handle_event("save", %{"task" => params}, socket) do
    attrs = %{
      title: params["title"],
      description: params["description"],
      status: params["status"],
      due_on: parse_date(params["due_on"]),
      project_id: parse_int(params["project_id"]),
      assignee_id: parse_int(params["assignee_id"])
    }

    case Eams.create_task(attrs) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form_data, %{
           "title" => "",
           "description" => "",
           "status" => "pending",
           "due_on" => "",
           "project_id" => "",
           "assignee_id" => ""
         })
         |> assign(:tasks, load_tasks())
         |> assign(:attachees, Eams.list_attachees())
         |> assign(:errors, %{})
         |> put_flash(:info, "Task created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, errors: changeset.errors |> Enum.into(%{}))}
    end
  end

  # Helper Functions

  defp filtered_tasks(tasks, "all"), do: tasks
  defp filtered_tasks(tasks, status), do: Enum.filter(tasks, &(&1.status == status))

  defp get_attachee_name(attachee) do
    cond do
      attachee.first_name && attachee.last_name ->
        "#{attachee.first_name} #{attachee.last_name}"

      attachee.user && attachee.user.username ->
        attachee.user.username

      attachee.user && attachee.user.email ->
        attachee.user.email

      true ->
        "Attachee ##{attachee.id}"
    end
  end

  defp get_initials(attachee) do
    cond do
      attachee.first_name && attachee.last_name ->
        "#{String.first(attachee.first_name)}#{String.first(attachee.last_name)}"

      attachee.user && attachee.user.username ->
        String.slice(attachee.user.username, 0..1) |> String.upcase()

      true ->
        "A"
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp relative_date(due_date) do
    today = Date.utc_today()
    diff = Date.diff(due_date, today)

    cond do
      diff < 0 -> "#{abs(diff)} days overdue"
      diff == 0 -> "Due today"
      diff == 1 -> "Due tomorrow"
      diff <= 7 -> "Due in #{diff} days"
      true -> "Due in #{div(diff, 7)} weeks"
    end
  end

  defp due_date_color(due_date) do
    today = Date.utc_today()
    diff = Date.diff(due_date, today)

    cond do
      diff < 0 -> "text-red-600 font-semibold"
      diff == 0 -> "text-orange-600 font-semibold"
      diff <= 3 -> "text-yellow-600"
      true -> "text-gray-500"
    end
  end

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp status_badge_class(status) do
    base = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold"

    color =
      case status do
        "pending" -> "bg-yellow-100 text-yellow-800"
        "in_progress" -> "bg-blue-100 text-blue-800"
        "blocked" -> "bg-red-100 text-red-800"
        "completed" -> "bg-green-100 text-green-800"
        "cancelled" -> "bg-gray-100 text-gray-800"
        _ -> "bg-gray-100 text-gray-800"
      end

    "#{base} #{color}"
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    {:ok, date} = Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d))
    date
  end
end
