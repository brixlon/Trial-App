defmodule TrialAppWeb.AttacheeDashboardLive do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams

  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope

    attachee =
      case current_scope.user do
        nil -> nil
        user ->
          # If the user is not an attachee yet, we will render an empty state
          Eams.get_attachee_by_user!(user.id)
      end

    programs = if attachee, do: Eams.list_programs_for_attachee(attachee.id), else: []
    tasks = if attachee, do: Eams.list_tasks_for_attachee(attachee.id), else: []
    projects = if attachee, do: Eams.list_projects_for_attachee(attachee.id), else: []

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:attachee, attachee)
     |> assign(:programs, programs)
     |> assign(:tasks, tasks)
     |> assign(:projects, projects)}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />
    <div class="ml-64 p-8">
      <div class="bg-white/70 backdrop-blur-sm rounded-2xl shadow-lg p-6 border border-purple-100">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">My Dashboard</h1>
            <p class="text-gray-600 mt-1">Welcome back, {@current_scope.user.username || @current_scope.user.email}</p>
          </div>
        </div>

        <%= if @attachee do %>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div class="bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl p-6 text-white shadow-lg">
              <div class="text-sm">Organization</div>
              <div class="text-2xl font-bold mt-2">{@attachee.organization && @attachee.organization.name}</div>
            </div>
            <div class="bg-gradient-to-br from-blue-500 to-cyan-600 rounded-xl p-6 text-white shadow-lg">
              <div class="text-sm">Department</div>
              <div class="text-2xl font-bold mt-2">{@attachee.department && @attachee.department.name}</div>
            </div>
            <div class="bg-gradient-to-br from-emerald-500 to-teal-600 rounded-xl p-6 text-white shadow-lg">
              <div class="text-sm">Programs Enrolled</div>
              <div class="text-2xl font-bold mt-2">{length(@programs)}</div>
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Programs -->
            <div class="bg-white rounded-xl border p-5">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-semibold text-gray-900">My Programs</h2>
              </div>
              <%= if @programs == [] do %>
                <div class="text-gray-600">You are not enrolled in any program yet.</div>
              <% else %>
                <ul class="space-y-3">
                  <%= for prog <- @programs do %>
                    <li class="p-4 rounded-lg border hover:border-indigo-200 hover:shadow transition">
                      <div class="font-semibold text-gray-900">{prog.name}</div>
                      <div class="text-sm text-gray-500">
                        {prog.organization && prog.organization.name} • {prog.department && prog.department.name}
                      </div>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>

            <!-- Projects -->
            <div class="bg-white rounded-xl border p-5">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-semibold text-gray-900">My Projects</h2>
              </div>
              <%= if @projects == [] do %>
                <div class="text-gray-600">No projects assigned yet.</div>
              <% else %>
                <ul class="space-y-3">
                  <%= for pr <- @projects do %>
                    <li class="p-4 rounded-lg border hover:border-blue-200 hover:shadow transition">
                      <div class="font-semibold text-gray-900">{pr.name}</div>
                      <div class="text-sm text-gray-500">{pr.description || ""}</div>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </div>

          <!-- Tasks -->
          <div class="bg-white rounded-xl border p-5 mt-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-gray-900">My Tasks</h2>
            </div>
            <%= if @tasks == [] do %>
              <div class="text-gray-600">No tasks assigned yet.</div>
            <% else %>
              <div class="overflow-hidden rounded-xl border">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gradient-to-r from-gray-50 to-slate-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Title</th>
                      <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Project</th>
                      <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Status</th>
                      <th class="px-6 py-3 text-left text-xs font-bold text-gray-600 uppercase tracking-wider">Due</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-100">
                    <%= for t <- @tasks do %>
                      <tr class="hover:bg-gradient-to-r hover:from-indigo-50 hover:to-purple-50 transition">
                        <td class="px-6 py-3">{t.title}</td>
                        <td class="px-6 py-3">{t.project && t.project.name}</td>
                        <td class="px-6 py-3">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-800 border border-gray-200">{t.status}</span>
                        </td>
                        <td class="px-6 py-3">{t.due_on && to_string(t.due_on) || "—"}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-gray-600">No attachee profile found for your account.</div>
        <% end %>
      </div>
    </div>
    """
  end
end
