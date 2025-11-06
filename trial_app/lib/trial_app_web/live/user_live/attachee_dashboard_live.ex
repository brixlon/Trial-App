defmodule TrialAppWeb.AttacheeDashboardLive do
  use TrialAppWeb, :live_view
  import Phoenix.LiveView.JS

  alias TrialApp.Eams
  alias TrialApp.Repo

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user

    attachee = Eams.get_attachee_by_user(user.id)

    if attachee do
      programs = Eams.list_programs_for_attachee(attachee.id)
      tasks = Eams.list_tasks_for_attachee(attachee.id) |> Repo.preload([:project])
      projects = Eams.list_projects_for_attachee(attachee.id)
      team_mates = get_team_mates(attachee.department_id)

      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:attachee, attachee)
       |> assign(:programs, programs)
       |> assign(:tasks, tasks)
       |> assign(:projects, projects)
       |> assign(:team_mates, team_mates)
       |> assign(:show_task_modal, false)
       |> assign(:selected_task, nil)
       |> assign(:submission_comment, "")}
    else
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:attachee, nil)
       |> put_flash(:error, "No attachee profile found. Please contact your admin.")}
    end
  end

  # Open modal
  def handle_event("open_submit_modal", %{"task_id" => task_id}, socket) do
    task = Enum.find(socket.assigns.tasks, &(&1.id == String.to_integer(task_id)))
    {:noreply,
     socket
     |> assign(:show_task_modal, true)
     |> assign(:selected_task, task)
     |> assign(:submission_comment, "")}
  end

  # Close modal
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_task_modal, false)
     |> assign(:selected_task, nil)
     |> assign(:submission_comment, "")}
  end

  # Submit task with comment
  def handle_event("submit_task", %{"comment" => comment}, socket) do
    task = socket.assigns.selected_task

    case Eams.submit_attachee_task(task.id, %{comment: comment}) do
      {:ok, _} ->
        updated_tasks = Eams.list_tasks_for_attachee(socket.assigns.attachee.id) |> Repo.preload([:project])
        {:noreply,
         socket
         |> assign(:tasks, updated_tasks)
         |> assign(:show_task_modal, false)
         |> assign(:selected_task, nil)
         |> put_flash(:info, "Task submitted successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to submit task.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

    <div class="ml-64 p-8 bg-gray-50 min-h-screen">
      <%= if @attachee do %>
        <!-- HEADER -->
        <div class="bg-white/80 backdrop-blur-sm rounded-2xl shadow-lg p-6 border border-purple-100 mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Attachee Dashboard</h1>
              <p class="text-gray-600 mt-1">Welcome back, <%= @attachee.user.username || @attachee.user.email %></p>
            </div>
            <div class="flex gap-3">
              <span class="px-4 py-1.5 bg-green-100 text-green-800 rounded-full text-sm font-semibold">
                <%= length(@tasks) %> Active Tasks
              </span>
              <span class="px-4 py-1.5 bg-indigo-100 text-indigo-800 rounded-full text-sm font-semibold">
                <%= length(@projects) %> Projects
              </span>
            </div>
          </div>
        </div>

        <!-- PROFILE CARD -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-8 border border-gray-100">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center space-x-4">
              <div class="w-16 h-16 bg-indigo-100 rounded-full flex items-center justify-center">
                <span class="text-indigo-700 font-bold text-xl">
                  <%= String.first(@attachee.user.username || @attachee.user.email) |> String.upcase() %>
                </span>
              </div>
              <div>
                <h2 class="text-xl font-semibold text-gray-900">
                  <%= @attachee.user.username || @attachee.user.email %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 ml-2">
                    Attachee
                  </span>
                </h2>
                <p class="text-sm text-gray-500">ID: INT<%= String.pad_leading(to_string(@attachee.id), 4, "0") %></p>
              </div>
            </div>
            <button class="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm hover:bg-indigo-700">
              View Profile
            </button>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
            <div class="text-center">
              <div class="text-2xl font-bold text-indigo-600"><%= @attachee.position %></div>
              <div class="text-sm text-gray-500 mt-1">Position</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600"><%= @attachee.organization.name %></div>
              <div class="text-sm text-gray-500 mt-1">Organization</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600"><%= @attachee.department.name %></div>
              <div class="text-sm text-gray-500 mt-1">Department</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">
                <%= length(@programs) %> Program<%= if length(@programs) != 1, do: "s" %>
              </div>
              <div class="text-sm text-gray-500 mt-1">Enrolled</div>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 text-center text-sm">
            <div>
              <div class="font-medium text-gray-700 mb-1">Job Level</div>
              <div class="text-gray-600">Beginner</div>
            </div>
            <div>
              <div class="font-medium text-gray-700 mb-1">Contract Start</div>
              <div class="text-gray-600"><%= format_date(@attachee.starts_on) %></div>
            </div>
            <div>
              <div class="font-medium text-gray-700 mb-1">Contract End</div>
              <div class="text-gray-600"><%= format_date(@attachee.ends_on) %></div>
            </div>
          </div>
        </div>

        <!-- PROGRAMS & PROJECTS -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <!-- Enrolled Programs -->
          <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Enrolled Programs</h3>
            <%= if @programs == [] do %>
              <p class="text-gray-500 text-center py-6">No programs enrolled.</p>
            <% else %>
              <div class="space-y-3">
                <%= for program <- @programs do %>
                  <div class="p-3 border rounded-lg hover:shadow-sm transition">
                    <h4 class="font-medium text-gray-900"><%= program.name %></h4>
                    <p class="text-xs text-gray-500"><%= program.description || "Ongoing training" %></p>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Assigned Projects -->
          <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Assigned Projects</h3>
            <%= if @projects == [] do %>
              <p class="text-gray-500 text-center py-6">No projects assigned yet.</p>
            <% else %>
              <div class="space-y-3">
                <%= for project <- @projects do %>
                  <div class="p-3 border rounded-lg hover:shadow-sm transition">
                    <div class="flex justify-between items-center">
                      <div>
                        <h4 class="font-medium text-gray-900"><%= project.name %></h4>
                        <p class="text-xs text-gray-500"><%= project.description || "No description" %></p>
                      </div>
                      <span class="px-2 py-1 text-xs rounded-full bg-indigo-100 text-indigo-700">
                        <%= count_tasks_in_project(@tasks, project.id) %> tasks
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- MY TASKS TABLE -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-8 border border-gray-100">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">My Tasks</h2>
          <%= if @tasks == [] do %>
            <div class="text-center py-10 text-gray-500">
              <p class="text-lg">No tasks assigned yet.</p>
              <p class="text-sm mt-1">Check back later or contact your supervisor.</p>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gradient-to-r from-gray-50 to-slate-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Task</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Project</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Status</th>
                    <th class="px- Lage py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Due Date</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Action</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-100">
                  <%= for task <- @tasks do %>
                    <tr class="hover:bg-indigo-50 transition">
                      <td class="px-6 py-4">
                        <div class="font-medium text-gray-900"><%= task.title %></div>
                        <%= if task.description do %>
                          <p class="text-sm text-gray-500 mt-1"><%= truncate(task.description, 80) %></p>
                        <% end %>
                        <%= if task.reject_reason do %>
                          <div class="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs">
                            <span class="font-medium text-red-800">Feedback:</span>
                            <span class="text-red-700"><%= task.reject_reason %></span>
                          </div>
                        <% end %>
                      </td>
                      <td class="px-6 py-4">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                          <%= task.project && task.project.name %>
                        </span>
                      </td>
                      <td class="px-6 py-4">
                        <span class={status_badge_class(task.status)}><%= format_status(task.status) %></span>
                      </td>
                      <td class="px-6 py-4 text-sm">
                        <%= if task.due_on do %>
                          <div class="font-medium"><%= format_date(task.due_on) %></div>
                          <div class={due_date_class(task.due_on)}><%= relative_date(task.due_on) %></div>
                        <% else %>
                          <span class="text-gray-400">—</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4">
                        <%= if task.status in ["pending", "in_progress", "rejected"] do %>
                          <button
                            phx-click="open_submit_modal"
                            phx-value-task_id={task.id}
                            class="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition"
                          >
                            <%= if task.status == "in_progress", do: "Submit", else: "Submit Work" %>
                          </button>
                        <% else %>
                          <span class="text-sm text-gray-500">
                            <%= if task.status == "submitted", do: "Under Review", else: "Completed" %>
                          </span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>

        <!-- TEAM MATES TABLE -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-8 border border-gray-100">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold text-gray-900">Team Mates</h2>
            <span class="text-sm text-gray-500"><%= @attachee.department.name %> Team</span>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Position</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for mate <- @team_mates do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="flex-shrink-0 h-10 w-10">
                          <span class="inline-flex h-10 w-10 items-center justify-center rounded-full bg-indigo-100 text-indigo-700 font-bold text-sm">
                            <%= String.first(mate.user.username || mate.user.email) |> String.upcase() %>
                          </span>
                        </div>
                        <div class="ml-4">
                          <div class="text-sm font-medium text-gray-900"><%= mate.user.username || mate.user.email %></div>
                          <div class="text-sm text-gray-500">INT<%= String.pad_leading(to_string(mate.id), 4, "0") %></div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= obscure_email(mate.user.email) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                        <%= mate.position || "Member" %>
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- SUBMISSION MODAL -->
        <%= if @show_task_modal && @selected_task do %>
          <div
            id="submit-task-modal"
            class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
            phx-click-away={JS.push("close_modal")}
            phx-window-keydown={JS.push("close_modal")}
            phx-key="Escape"
          >
            <div
              class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6"
              phx-click={JS.nothing()}
            >
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-gray-900">
                  Submit Task: <%= @selected_task.title %>
                </h2>
                <button
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <p class="text-sm text-gray-600 mb-5">
                Add your comments or notes about the work done.
              </p>

              <form phx-submit="submit_task" class="space-y-5">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Comments</label>
                  <textarea
                    name="comment"
                    rows="5"
                    class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 resize-none"
                    placeholder="Describe what you did, challenges faced, or any questions..."
                    required
                  ><%= @submission_comment %></textarea>
                </div>

                <div class="flex justify-end gap-3 pt-3">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="px-5 py-2.5 border border-gray-300 rounded-xl text-gray-700 hover:bg-gray-50 font-medium transition"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-5 py-2.5 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 font-medium transition shadow-sm"
                  >
                    Submit Task
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>

      <% else %>
        <!-- NO PROFILE -->
        <div class="bg-white rounded-2xl shadow-lg p-12 text-center border border-gray-200">
          <div class="mx-auto w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mb-4">
            <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H9v-1a4 4 0 014-4h2a4 4 0 014 4v1z" />
            </svg>
          </div>
          <h3 class="text-xl font-semibold text-gray-900 mb-2">No Attachee Profile</h3>
          <p class="text-gray-600">Please contact HR to complete your onboarding.</p>
        </div>
      <% end %>
    </div>
    """
  end

  # === HELPER FUNCTIONS ===
  defp get_team_mates(department_id) do
    Eams.list_attachees_by_department(department_id, %{preloads: [:user]})
  end

  defp count_tasks_in_project(tasks, project_id) do
    Enum.count(tasks, &(&1.project_id == project_id))
  end

  defp truncate(text, length) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end

  defp format_date(date), do: if(date, do: Calendar.strftime(date, "%b %d, %Y"), else: "Not set")

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp status_badge_class("pending"), do: "px-2.5 py-0.5 bg-yellow-100 text-yellow-800 rounded-full text-xs font-medium"
  defp status_badge_class("in_progress"), do: "px-2.5 py-0.5 bg-blue-100 text-blue-800 rounded-full text-xs font-medium"
  defp status_badge_class("submitted"), do: "px-2.5 py-0.5 bg-indigo-100 text-indigo-800 rounded-full text-xs font-medium"
  defp status_badge_class("completed"), do: "px-2.5 py-0.5 bg-green-100 text-green-800 rounded-full text-xs font-medium"
  defp status_badge_class("rejected"), do: "px-2.5 py-0.5 bg-red-100 text-red-800 rounded-full text-xs font-medium"
  defp status_badge_class(_), do: "px-2.5 py-0.5 bg-gray-100 text-gray-800 rounded-full text-xs font-medium"

  defp due_date_class(due_date) do
    diff = Date.diff(due_date, Date.utc_today())
    cond do
      diff < 0 -> "text-red-600 text-xs font-medium"
      diff <= 2 -> "text-orange-600 text-xs font-medium"
      diff <= 7 -> "text-yellow-600 text-xs"
      true -> "text-gray-500 text-xs"
    end
  end

  defp relative_date(due_date) do
    diff = Date.diff(due_date, Date.utc_today())
    cond do
      diff < 0 -> "Overdue"
      diff == 0 -> "Today"
      diff == 1 -> "Tomorrow"
      diff <= 7 -> "In #{diff} days"
      true -> "In #{div(diff, 7)} weeks"
    end
  end

  defp obscure_email(email) do
    [name, domain] = String.split(email, "@")
    obscured = String.slice(name, 0, 3) <> "****"
    obscured <> "@" <> domain
  end
end
