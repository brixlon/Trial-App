defmodule TrialAppWeb.SupervisorLive.Projects do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Get projects for the supervisor
    projects = Eams.list_projects_for_supervisor(current_user.id)

    {:ok, assign(socket, projects: projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <div class="mb-6">
        <h1 class="text-3xl font-bold text-gray-800">Projects</h1>
        <p class="text-gray-600 mt-2">View and manage projects assigned to your team</p>
      </div>

      <%= if Enum.empty?(@projects) do %>
        <div class="bg-gray-50 rounded-lg border border-gray-200 p-8 text-center">
          <p class="text-gray-600">No projects found</p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for project <- @projects do %>
            <div class="bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition">
              <h3 class="text-lg font-semibold text-gray-800 mb-2"><%= project.name %></h3>
              <p class="text-gray-600 text-sm mb-4"><%= project.description %></p>
              <div class="flex items-center justify-between text-sm text-gray-500">
                <span><%= project.status %></span>
                <a href="#" class="text-indigo-600 hover:text-indigo-700 font-medium">View →</a>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
