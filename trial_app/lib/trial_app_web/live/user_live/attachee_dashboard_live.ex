defmodule TrialAppWeb.AttacheeDashboardLive do
  use TrialAppWeb, :live_view
  

  alias TrialApp.Eams
  alias TrialApp.Repo

  def mount(_params, _session, socket) do
  current_scope = socket.assigns.current_scope
  user = current_scope.user

  # SOFT LOOKUP — no crash if no attachee
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
     |> assign(:team_mates, team_mates)}
  else
    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:attachee, nil)
     |> put_flash(:error, "No attachee profile found. Please contact your admin.")}
  end
end

  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />
    <div class="ml-64 p-8">
      <%= if @attachee do %>
        <!-- HEADER -->
        <div class="bg-white/70 backdrop-blur-sm rounded-2xl shadow-lg p-6 border border-purple-100 mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
              <p class="text-gray-600 mt-1">Welcome back, <%= @current_scope.user.username || @current_scope.user.email %></p>
            </div>
            <div class="flex gap-2">
              <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-medium">
                <%= length(@tasks) %> Tasks
              </span>
              <span class="px-3 py-1 bg-indigo-100 text-indigo-800 rounded-full text-sm font-medium">
                <%= length(@projects) %> Projects
              </span>
            </div>
          </div>
        </div>

        <!-- PROFILE OVERVIEW -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-8 border border-gray-100">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Profile Overview</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div class="text-center">
              <div class="text-2xl font-bold text-indigo-600"><%= @attachee.position || "Software Developer Attachee" %></div>
              <div class="text-sm text-gray-500">Position</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600"><%= @attachee.organization.name %></div>
              <div class="text-sm text-gray-500">Organization</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600"><%= @attachee.department.name %></div>
              <div class="text-sm text-gray-500">Department</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">
                <%= length(@programs) %> Program<%= if length(@programs) != 1, do: "s" %>
              </div>
              <div class="text-sm text-gray-500">Enrolled</div>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-6">
            <div class="text-center">
              <div class="text-lg font-semibold">Contract</div>
              <div class="text-sm text-gray-500">
                <%= if @attachee.starts_on && @attachee.ends_on do %>
                  <%= Date.to_string(@attachee.starts_on) %> - <%= Date.to_string(@attachee.ends_on) %>
                <% else %>
                  Not set
                <% end %>
              </div>
            </div>
            <div class="text-center">
              <div class="text-lg font-semibold">Job Level</div>
              <div class="text-sm text-gray-500">Beginner</div>
            </div>
            <div class="text-center">
              <div class="text-lg font-semibold">Work Remotely</div>
              <div class="text-sm text-green-600">Yes</div>
            </div>
          </div>
        </div>

        <!-- LEAVE & EVALUATION -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
            <h3 class="text-lg font-semibold mb-4">Leave Summary</h3>
            <div class="grid grid-cols-2 gap-6">
              <div class="text-center">
                <div class="text-3xl font-bold text-indigo-600">0.00/21</div>
                <div class="text-sm text-gray-500">Available Annual Leave Days</div>
              </div>
              <div class="text-center">
                <div class="text-3xl font-bold text-blue-600">0.00</div>
                <div class="text-sm text-gray-500">Ad Hoc Leave Days</div>
              </div>
            </div>
            <div class="mt-4 p-4 bg-gray-50 rounded-lg">
              <h4 class="font-medium mb-2">Planned Leave</h4>
              <p class="text-sm text-gray-600">No planned leaves</p>
            </div>
          </div>

          <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
            <h3 class="text-lg font-semibold mb-4">Evaluation Summary</h3>
            <div class="flex items-center justify-between mb-4">
              <div class="text-3xl font-bold text-yellow-600">0/5</div>
              <div class="text-sm text-gray-500">Not Meeting Expectations</div>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2 mb-4">
              <div class="bg-gradient-to-r from-red-400 to-red-600 h-2 rounded-full" style="width: 0%"></div>
            </div>
            <div class="flex justify-between text-xs">
              <span>0 Evaluations</span>
              <span>Most Recent</span>
              <span>Next Evaluation</span>
            </div>
          </div>
        </div>

        <!-- TEAM MATES -->
        <div class="bg-white rounded-2xl shadow-lg p-6 mb-8 border border-gray-100">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Team Mates</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <%= for mate <- @team_mates do %>
              <div class="text-center p-4 border rounded-lg hover:shadow-md transition">
                <div class="w-12 h-12 bg-indigo-100 rounded-full mx-auto flex items-center justify-center mb-2">
                  <span class="text-indigo-600 font-semibold">
                    <%= mate.user.username |> String.first() |> String.upcase() %>
                  </span>
                </div>
                <h4 class="font-medium"><%= mate.user.username || mate.user.email %></h4>
                <p class="text-xs text-gray-500"><%= mate.position || "Team Member" %></p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- MY TASKS -->
        <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">My Tasks</h2>
          <%= if @tasks == [] do %>
            <div class="text-gray-500 text-center py-8">
              No tasks assigned yet.
            </div>
          <% else %>
            <div class="overflow-hidden rounded-xl border">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gradient-to-r from-gray-50 to-slate-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Title</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Project</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Status</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Due</th>
                    <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <%= for task <- @tasks do %>
                    <tr class="hover:bg-gradient-to-r hover:from-indigo-50 hover:to-purple-50 transition">
                      <td class="px-6 py-4">
                        <div>
                          <div class="font-medium text-gray-900"><%= task.title %></div>
                          <%= if task.description do %>
                            <div class="text-sm text-gray-500 mt-1"><%= task.description %></div>
                          <% end %>
                        </div>
                        <!-- REJECT REASON FEEDBACK -->
                        <%= if task.reject_reason do %>
                          <div class="mt-2 p-2 bg-yellow-50 border border-yellow-200 rounded text-xs">
                            <div class="font-medium text-yellow-800">Feedback from Admin:</div>
                            <div class="text-yellow-700"><%= task.reject_reason %></div>
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
                      <td class="px-6 py-4">
                        <%= if task.due_on do %>
                          <div class="text-sm text-gray-900"><%= format_date(task.due_on) %></div>
                          <div class={due_date_class(task.due_on)}><%= relative_date(task.due_on) %></div>
                        <% else %>
                          <span class="text-gray-400">No due date</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4">
                        <%= if task.status in ["pending", "in_progress"] do %>
                          <button
                            phx-click={JS.navigate("/attachee/tasks/#{task.id}/submit")}
                            class="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 transition"
                          >
                            <%= if task.status == "in_progress", do: "Resubmit", else: "Start Work" %>
                          </button>
                        <% else %>
                          <span class="text-sm text-gray-500">
                            <%= if task.status == "submitted", do: "Under Review", else: task.status |> String.capitalize() %>
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

        <!-- COMPANY POLICIES & TRAINING -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
          <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
            <h3 class="text-lg font-semibold mb-4">Company Policies</h3>
            <div class="space-y-3">
              <a href="#" class="block p-3 border rounded-lg hover:bg-gray-50 transition">
                <h4 class="font-medium">Code of Conduct</h4>
                <p class="text-sm text-gray-600">Our expectations for professional behavior</p>
              </a>
              <a href="#" class="block p-3 border rounded-lg hover:bg-gray-50 transition">
                <h4 class="font-medium">Leave Policy</h4>
                <p class="text-sm text-gray-600">Guidelines for requesting time off</p>
              </a>
            </div>
          </div>

          <div class="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
            <h3 class="text-lg font-semibold mb-4">Training & Development</h3>
            <div class="space-y-3">
              <div class="p-3 border rounded-lg bg-indigo-50">
                <h4 class="font-medium">Software Development Basics</h4>
                <p class="text-sm text-gray-600">Complete by Dec 15, 2025</p>
                <div class="mt-2 flex justify-between">
                  <div class="w-24 bg-gray-200 rounded-full h-2">
                    <div class="bg-indigo-600 h-2 rounded-full" style="width: 60%"></div>
                  </div>
                  <span class="text-sm text-gray-500">60%</span>
                </div>
              </div>
            </div>
          </div>
        </div>

      <% else %>
        <!-- NO PROFILE STATE -->
        <div class="bg-white rounded-2xl shadow-lg p-12 text-center border border-gray-200">
          <svg class="mx-auto h-16 w-16 text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H9v-1a4 4 0 014-4h2a4 4 0 014 4v1z" />
          </svg>
          <h3 class="text-xl font-semibold text-gray-900 mb-2">No Attachee Profile</h3>
          <p class="text-gray-600 mb-4">
            Your account is not linked to an attachee profile yet.
          </p>
          <p class="text-sm text-gray-500">
            Please contact your supervisor or admin to complete your onboarding.
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # === HELPER FUNCTIONS ===
  defp get_team_mates(department_id) do
    Eams.list_attachees_by_department(department_id, %{preloads: [:user]})
  end

  defp format_date(date), do: Calendar.strftime(date, "%b %d, %Y")

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp status_badge_class("pending"), do: "px-2.5 py-0.5 bg-yellow-100 text-yellow-800 rounded-full text-xs"
  defp status_badge_class("in_progress"), do: "px-2.5 py-0.5 bg-blue-100 text-blue-800 rounded-full text-xs"
  defp status_badge_class("submitted"), do: "px-2.5 py-0.5 bg-indigo-100 text-indigo-800 rounded-full text-xs"
  defp status_badge_class("completed"), do: "px-2.5 py-0.5 bg-green-100 text-green-800 rounded-full text-xs"
  defp status_badge_class(_), do: "px-2.5 py-0.5 bg-gray-100 text-gray-800 rounded-full text-xs"

  defp due_date_class(due_date) do
    diff = Date.diff(due_date, Date.utc_today())
    cond do
      diff < 0 -> "text-red-600 font-medium"
      diff <= 3 -> "text-yellow-600"
      true -> "text-gray-500"
    end
  end

  defp relative_date(due_date) do
    diff = Date.diff(due_date, Date.utc_today())
    cond do
      diff < 0 -> "#{abs(diff)} days overdue"
      diff == 0 -> "Today"
      diff == 1 -> "Tomorrow"
      diff <= 7 -> "In #{diff} days"
      true -> "In #{div(diff, 7)} weeks"
    end
  end
end
