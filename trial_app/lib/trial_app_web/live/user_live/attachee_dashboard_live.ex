defmodule TrialAppWeb.AttacheeDashboardLive do
  use TrialAppWeb, :live_view
  import Phoenix.LiveView.JS

  alias TrialApp.{Accounts, Eams, Repo}

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

      # Get REAL evaluation data
      evaluations = Eams.list_evaluations_for_attachee(attachee.id, %{preloads: [:evaluator]})
      avg_score = Eams.get_average_evaluation_score(attachee.id)
      eval_count = Eams.count_evaluations_for_attachee(attachee.id)
      evaluation_data = Eams.get_evaluation_categories_for_attachee(attachee.id)

      # Calculate not meeting expectations (scores below 41)
      not_meeting = Enum.count(evaluation_data, fn cat -> cat.score < 41 end)

      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:attachee, attachee)
       |> assign(:programs, programs)
       |> assign(:tasks, tasks)
       |> assign(:projects, projects)
       |> assign(:team_mates, team_mates)
       |> assign(:evaluations, evaluations)
       |> assign(:evaluation_data, evaluation_data)
       |> assign(:avg_score, avg_score)
       |> assign(:eval_count, eval_count)
       |> assign(:not_meeting, not_meeting)
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

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # Open modal
  @impl true
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
  def handle_info({:switch_role, new_role}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.switch_user_role(user, new_role) do
      {:ok, updated_user} ->
        # Update the socket with the new user data
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        # Redirect to the appropriate dashboard for the new role
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
         |> put_flash(:info, "Switched to #{new_role} role")
         |> push_navigate(to: redirect_path)}

      {:error, :unauthorized_role} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to switch to that role")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to switch role")}
    end
  end

  @impl true
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
                <h1 class="text-2xl font-semibold text-gray-800">Dashboard</h1>
                <p class="text-gray-600 mt-1">View an overview of your employee information</p>
              </div>
              <div class="flex gap-3">
                <span class="px-4 py-2 bg-green-100 text-green-800 rounded-lg text-sm font-semibold">
                  <%= length(@tasks) %> Active Tasks
                </span>
                <span class="px-4 py-2 bg-purple-100 text-purple-800 rounded-lg text-sm font-semibold">
                  <%= length(@projects) %> Projects
                </span>
              </div>
            </div>

            <!-- Overview Section -->
            <div class="bg-gray-50 p-6 rounded-xl shadow">
              <h2 class="text-lg font-semibold text-gray-800 mb-4">Overview</h2>

              <!-- User Info -->
              <div class="flex items-center space-x-4 mb-6">
                <div class="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
                  <span class="text-purple-700 font-bold text-lg">
                    <%= String.first(@attachee.user.username || @attachee.user.email) |> String.upcase() %>
                  </span>
                </div>
                <div>
                  <div class="font-semibold text-gray-900">
                    <%= String.upcase(@attachee.user.username || String.split(@attachee.user.email, "@") |> hd()) %>
                  </div>
                  <div class="text-sm text-gray-600">Attachee INT<%= String.pad_leading(to_string(@attachee.id), 4, "0") %></div>
                </div>
              </div>

              <!-- Position & Job Level Table -->
              <div class="mb-6">
                <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
                  <table class="min-w-full text-sm">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-4 py-3 text-left font-medium text-gray-700">Position</th>
                        <th class="px-4 py-3 text-left font-medium text-gray-700">Job Level</th>
                        <th class="px-4 py-3 text-left font-medium text-gray-700">Current Contract Start Date</th>
                        <th class="px-4 py-3 text-left font-medium text-gray-700">Current Contract End Date</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                      <tr>
                        <td class="px-4 py-3 text-gray-900"><%= @attachee.position %></td>
                        <td class="px-4 py-3 text-gray-900">Beginner</td>
                        <td class="px-4 py-3 text-gray-900"><%= format_date(@attachee.starts_on) %></td>
                        <td class="px-4 py-3 text-gray-900"><%= format_date(@attachee.ends_on) %></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <!-- Programs & Projects -->
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <!-- Enrolled Programs -->
              <div class="bg-white shadow rounded-xl overflow-hidden">
                <div class="p-6">
                  <h3 class="text-lg font-semibold text-gray-800 mb-4">Enrolled Programs</h3>
                  <%= if @programs == [] do %>
                    <p class="text-gray-500 text-center py-6">No programs enrolled.</p>
                  <% else %>
                    <div class="space-y-3">
                      <%= for program <- @programs do %>
                        <div class="p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition">
                          <h4 class="font-medium text-gray-900"><%= program.name %></h4>
                          <p class="text-sm text-gray-500 mt-1"><%= program.description || "Ongoing training" %></p>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Assigned Projects -->
              <div class="bg-white shadow rounded-xl overflow-hidden">
                <div class="p-6">
                  <h3 class="text-lg font-semibold text-gray-800 mb-4">Assigned Projects</h3>
                  <%= if @projects == [] do %>
                    <p class="text-gray-500 text-center py-6">No projects assigned yet.</p>
                  <% else %>
                    <div class="space-y-3">
                      <%= for project <- @projects do %>
                        <div class="p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition">
                          <div class="flex justify-between items-center">
                            <div>
                              <h4 class="font-medium text-gray-900"><%= project.name %></h4>
                              <p class="text-sm text-gray-500 mt-1"><%= project.description || "No description" %></p>
                            </div>
                            <span class="px-2 py-1 text-xs rounded bg-purple-100 text-purple-700 font-medium">
                              <%= count_tasks_in_project(@tasks, project.id) %> tasks
                            </span>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- My Tasks Table -->
            <div class="bg-white shadow rounded-xl overflow-hidden">
              <div class="p-6">
                <h2 class="text-xl font-semibold text-gray-800 mb-4">My Tasks</h2>
                <%= if @tasks == [] do %>
                  <div class="text-center py-10 text-gray-500">
                    <p class="text-lg">No tasks assigned yet.</p>
                    <p class="text-sm mt-1">Check back later or contact your supervisor.</p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="min-w-full text-sm text-left text-gray-700">
                      <thead class="bg-gray-100 text-xs uppercase">
                        <tr>
                          <th class="px-4 py-3">Task</th>
                          <th class="px-4 py-3">Project</th>
                          <th class="px-4 py-3">Status</th>
                          <th class="px-4 py-3">Due Date</th>
                          <th class="px-4 py-3">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for task <- @tasks do %>
                          <tr class="border-t hover:bg-gray-50 transition">
                            <td class="px-4 py-3">
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
                            <td class="px-4 py-3">
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                <%= task.project && task.project.name %>
                              </span>
                            </td>
                            <td class="px-4 py-3">
                              <span class={status_badge_class(task.status)}>
                                <%= format_status(task.status) %>
                              </span>
                            </td>
                            <td class="px-4 py-3">
                              <%= if task.due_on do %>
                                <div class="font-medium text-gray-900"><%= format_date(task.due_on) %></div>
                                <div class={due_date_class(task.due_on)}>
                                  <%= relative_date(task.due_on) %>
                                </div>
                              <% else %>
                                <span class="text-gray-400">—</span>
                              <% end %>
                            </td>
                            <td class="px-4 py-3">
                              <%= if task.status in ["pending", "in_progress", "rejected"] do %>
                                <button
                                  phx-click="open_submit_modal"
                                  phx-value-task_id={task.id}
                                  class="bg-purple-600 text-white px-4 py-2 rounded-lg shadow hover:bg-purple-700 text-sm font-medium"
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
            </div>

            <!-- Team Mates Table -->
            <div class="bg-white shadow rounded-xl overflow-hidden">
              <div class="p-6">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="text-xl font-semibold text-gray-800">Team Mates</h2>
                  <span class="text-sm text-gray-500"><%= @attachee.department.name %> Team</span>
                </div>
                <div class="overflow-x-auto">
                  <table class="min-w-full text-sm text-left text-gray-700">
                    <thead class="bg-gray-100 text-xs uppercase">
                      <tr>
                        <th class="px-4 py-3">User</th>
                        <th class="px-4 py-3">Organization</th>
                        <th class="px-4 py-3">Department</th>
                        <th class="px-4 py-3">Program(s)</th>
                        <th class="px-4 py-3">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for mate <- @team_mates do %>
                        <tr class="border-t hover:bg-gray-50 transition">
                          <td class="px-4 py-3">
                            <div class="flex items-center">
                              <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center mr-3">
                                <span class="text-purple-700 font-bold text-xs">
                                  <%= String.first(mate.user.username || mate.user.email) |> String.upcase() %>
                                </span>
                              </div>
                              <div>
                                <div class="font-medium text-gray-900"><%= mate.user.username || mate.user.email %></div>
                                <div class="text-xs text-gray-500">INT<%= String.pad_leading(to_string(mate.id), 4, "0") %></div>
                              </div>
                            </div>
                          </td>
                          <td class="px-4 py-3"><%= mate.organization.name %></td>
                          <td class="px-4 py-3"><%= mate.department.name %></td>
                          <td class="px-4 py-3">
                            Attachee <%= format_date(mate.starts_on) %>-<%= format_date(mate.ends_on) %>
                          </td>
                          <td class="px-4 py-3">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              active
                            </span>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <!-- Account Evaluation Summary -->
            <div class="bg-gray-50 p-6 rounded-xl shadow">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-md font-semibold text-gray-800">Account Evaluation Summary</h3>
                <div class="text-sm">
                  <span class="text-gray-600">Total Evaluations</span>
                  <span class="font-bold text-purple-600 ml-2"><%= @eval_count %></span>
                </div>
              </div>

              <%= if @eval_count == 0 do %>
                <!-- No Evaluations Yet -->
                <div class="text-center py-12">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                  </svg>
                  <h4 class="text-lg font-semibold text-gray-900 mb-2">No Evaluations Yet</h4>
                  <p class="text-gray-600">Your supervisor will evaluate your performance soon.</p>
                </div>
              <% else %>
                <!-- Evaluation Chart -->
                <div class="space-y-4">
                  <%= for eval <- @evaluation_data do %>
                    <div class="flex items-center justify-between">
                      <div class="w-1/4">
                        <span class="text-sm font-medium text-gray-700"><%= eval.category %></span>
                      </div>
                      <div class="w-2/4">
                        <div class="w-full bg-gray-200 rounded-full h-3">
                          <div
                            class={"h-3 rounded-full #{score_bar_color(eval.score)}"}
                            style={"width: #{eval.score}%"}
                          ></div>
                        </div>
                      </div>
                      <div class="w-1/4 text-right">
                        <span class="text-sm font-semibold text-gray-900">
                          <%= eval.score %>/<%= eval.max %>
                        </span>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Overall Performance -->
                <div class="mt-6 p-4 bg-white rounded-lg border border-gray-200">
                  <div class="flex items-center justify-between">
                    <div>
                      <h4 class="font-semibold text-gray-900">Overall Performance</h4>
                      <p class="text-sm text-gray-600">Based on <%= @eval_count %> evaluation(s)</p>
                    </div>
                    <div class="text-right">
                      <div class={"text-2xl font-bold #{overall_score_color(@avg_score)}"}>
                        <%= @avg_score %>%
                      </div>
                      <div class={"text-sm font-medium #{overall_label_color(@avg_score)}"}>
                        <%= overall_label(@avg_score) %>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Recent Evaluations -->
                <div class="mt-6">
                  <h4 class="text-sm font-semibold text-gray-800 mb-3">Recent Evaluations</h4>
                  <div class="space-y-2">
                    <%= for evaluation <- Enum.take(@evaluations, 3) do %>
                      <div class="flex items-center justify-between p-3 bg-white rounded-lg border border-gray-200">
                        <div class="flex items-center gap-3">
                          <div class={"w-10 h-10 rounded-full flex items-center justify-center font-bold #{evaluation_badge_bg(evaluation.score)}"}>
                            <%= evaluation.score %>
                          </div>
                          <div>
                            <p class="text-sm font-medium text-gray-900">
                              <%= evaluation.evaluator.username || evaluation.evaluator.email %>
                            </p>
                            <p class="text-xs text-gray-500">
                              <%= Calendar.strftime(evaluation.inserted_at, "%b %d, %Y") %>
                            </p>
                          </div>
                        </div>
                        <span class={"px-2 py-1 text-xs rounded font-medium #{evaluation_badge_class(evaluation.score)}"}>
                          <%= evaluation_label(evaluation.score) %>
                        </span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Not Meeting Expectations -->
                <div class="mt-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="text-sm font-medium text-gray-700 mb-1">Areas Needing Improvement</div>
                      <div class={"text-2xl font-bold #{if @not_meeting > 0, do: "text-red-600", else: "text-green-600"}"}>
                        <%= @not_meeting %>/5
                      </div>
                    </div>
                    <%= if @not_meeting == 0 do %>
                      <div class="flex items-center gap-2 text-green-600">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <span class="text-sm font-medium">All areas meeting expectations!</span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>

      <!-- SUBMISSION MODAL -->
      <%= if @show_task_modal && @selected_task do %>
        <div
          id="submit-task-modal"
          class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
          phx-click-away={JS.push("close_modal")}
          phx-window-keydown={JS.push("close_modal")}
          phx-key="escape"
        >
          <div
            class="bg-white rounded-xl shadow-lg w-full max-w-lg mx-4 p-6"
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
                  class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 resize-none"
                  placeholder="Describe what you did, challenges faced, or any questions..."
                  required
                ><%= @submission_comment %></textarea>
              </div>

              <div class="flex justify-end gap-3 pt-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-5 py-2.5 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-5 py-2.5 bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium transition shadow"
                >
                  Submit Task
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # === HELPER FUNCTIONS ===
  defp get_team_mates(department_id) do
    Eams.list_attachees_by_department(department_id, %{preloads: [:user, :organization, :department]})
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

  defp format_date(date) do
    if date do
      Calendar.strftime(date, "%b %d, %Y")
    else
      "Not set"
    end
  end

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp status_badge_class("pending"), do: "px-2.5 py-0.5 bg-yellow-100 text-yellow-800 rounded-full text-xs font-medium"
  defp status_badge_class("in_progress"), do: "px-2.5 py-0.5 bg-blue-100 text-blue-800 rounded-full text-xs font-medium"
  defp status_badge_class("submitted"), do: "px-2.5 py-0.5 bg-purple-100 text-purple-800 rounded-full text-xs font-medium"
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

  # Evaluation helper functions
  defp score_bar_color(score) when score >= 81, do: "bg-gradient-to-r from-green-400 to-green-600"
  defp score_bar_color(score) when score >= 61, do: "bg-gradient-to-r from-blue-400 to-blue-600"
  defp score_bar_color(score) when score >= 41, do: "bg-gradient-to-r from-yellow-400 to-yellow-600"
  defp score_bar_color(_), do: "bg-gradient-to-r from-red-400 to-red-600"

  defp overall_score_color(score) when score >= 81, do: "text-green-600"
  defp overall_score_color(score) when score >= 61, do: "text-blue-600"
  defp overall_score_color(score) when score >= 41, do: "text-yellow-600"
  defp overall_score_color(_), do: "text-red-600"

  defp overall_label_color(score) when score >= 81, do: "text-green-600"
  defp overall_label_color(score) when score >= 61, do: "text-blue-600"
  defp overall_label_color(score) when score >= 41, do: "text-yellow-600"
  defp overall_label_color(_), do: "text-red-600"

  defp overall_label(score) when score >= 81, do: "Excellent"
  defp overall_label(score) when score >= 61, do: "Good"
  defp overall_label(score) when score >= 41, do: "Satisfactory"
  defp overall_label(score) when score > 0, do: "Needs Improvement"
  defp overall_label(_), do: "Not Evaluated"

  defp evaluation_badge_bg(score) when score >= 81, do: "bg-green-100 text-green-700"
  defp evaluation_badge_bg(score) when score >= 61, do: "bg-blue-100 text-blue-700"
  defp evaluation_badge_bg(score) when score >= 41, do: "bg-yellow-100 text-yellow-700"
  defp evaluation_badge_bg(_), do: "bg-red-100 text-red-700"

  defp evaluation_badge_class(score) when score >= 81, do: "bg-green-100 text-green-700"
  defp evaluation_badge_class(score) when score >= 61, do: "bg-blue-100 text-blue-700"
  defp evaluation_badge_class(score) when score >= 41, do: "bg-yellow-100 text-yellow-700"
  defp evaluation_badge_class(_), do: "bg-red-100 text-red-700"

  defp evaluation_label(score) when score >= 81, do: "Excellent"
  defp evaluation_label(score) when score >= 61, do: "Good"
  defp evaluation_label(score) when score >= 41, do: "Satisfactory"
  defp evaluation_label(_), do: "Needs Improvement"
end
