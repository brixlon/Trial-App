# lib/trial_app_web/live/admin_live/program_show.ex
defmodule TrialAppWeb.AdminLive.ProgramShow do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialAppWeb.BreadcrumbComponent

  def mount(%{"id" => id}, _session, socket) do
    program = Eams.get_program_with_projects(String.to_integer(id))
    projects = Eams.list_projects_by_program(program.id)
    stats = Eams.get_program_stats(program.id)

    breadcrumbs = [
      %{label: "Programs", link: ~p"/admin/eams/programs"},
      %{label: program.name, link: nil}
    ]

    {:ok,
     socket
     |> assign(:program, program)
     |> assign(:projects, projects)
     |> assign(:stats, stats)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, program.name)
     |> assign(:search_query, "")
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  defp filtered_projects(projects, ""), do: projects
  defp filtered_projects(projects, query) do
    query = String.downcase(query)
    Enum.filter(projects, fn project ->
      String.contains?(String.downcase(project.name || ""), query) ||
      (project.code && String.contains?(String.downcase(project.code), query))
    end)
  end

  defp project_status(project) do
    cond do
      !project.is_active -> :inactive
      project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt -> :completed
      project.starts_on && Date.compare(project.starts_on, Date.utc_today()) == :gt -> :upcoming
      true -> :active
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="flex">
        <!-- Sidebar -->
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <!-- Main Content -->
        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-6">
            <!-- Breadcrumb -->
            <BreadcrumbComponent.breadcrumb items={@breadcrumbs} />

            <!-- Program Header -->
            <div class="bg-gradient-to-r from-purple-600 to-purple-700 rounded-2xl shadow-xl p-8 text-white">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h1 class="text-4xl font-bold mb-2"><%= @program.name %></h1>
                  <%= if @program.code do %>
                    <span class="inline-block px-3 py-1 bg-white/20 backdrop-blur-sm text-sm font-medium rounded-full">
                      <%= @program.code %>
                    </span>
                  <% end %>
                  <%= if @program.description do %>
                    <p class="mt-4 text-purple-100 text-lg"><%= @program.description %></p>
                  <% end %>
                </div>
              </div>

              <!-- Program Info -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
                <%= if Ecto.assoc_loaded?(@program.organization) && @program.organization do %>
                  <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                    </svg>
                    <div>
                      <div class="text-xs text-purple-200">Organization</div>
                      <div class="font-medium"><%= @program.organization.name %></div>
                    </div>
                  </div>
                <% end %>
                <%= if Ecto.assoc_loaded?(@program.department) && @program.department do %>
                  <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                    </svg>
                    <div>
                      <div class="text-xs text-purple-200">Department</div>
                      <div class="font-medium"><%= @program.department.name %></div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Stats Overview -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-purple-500">
                <div class="text-sm font-medium text-gray-600">Total Projects</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.total_projects %></div>
              </div>
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-green-500">
                <div class="text-sm font-medium text-gray-600">Active Projects</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.active_projects %></div>
              </div>
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-blue-500">
                <div class="text-sm font-medium text-gray-600">Total Attachees</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.total_attachees %></div>
              </div>
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-amber-500">
                <div class="text-sm font-medium text-gray-600">Active Attachees</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.active_attachees %></div>
              </div>
            </div>

            <!-- Search Bar -->
            <div class="bg-white rounded-xl shadow-sm p-4">
              <form phx-change="search" class="flex gap-4">
                <div class="flex-1">
                  <div class="relative">
                    <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                    </svg>
                    <input
                      type="text"
                      name="query"
                      value={@search_query}
                      placeholder="Search projects..."
                      class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                    />
                  </div>
                </div>
              </form>
            </div>

            <!-- Projects List -->
            <div class="bg-white rounded-xl shadow-sm overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200">
                <h2 class="text-xl font-bold text-gray-900">Projects</h2>
                <p class="text-sm text-gray-600 mt-1">Click on a project to view details and attachees</p>
              </div>

              <%= if filtered_projects(@projects, @search_query) == [] do %>
                <div class="p-12 text-center">
                  <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  <h3 class="text-lg font-medium text-gray-900 mb-2">No projects found</h3>
                  <p class="text-gray-600">This program doesn't have any projects yet</p>
                </div>
              <% else %>
                <div class="divide-y divide-gray-200">
                  <%= for project <- filtered_projects(@projects, @search_query) do %>
                    <.link
                      navigate={~p"/admin/eams/programs/#{@program.id}/projects/#{project.id}"}
                      class="block hover:bg-gray-50 transition-colors p-6"
                    >
                      <div class="flex items-start justify-between">
                        <div class="flex-1">
                          <div class="flex items-center gap-3 mb-2">
                            <h3 class="text-lg font-semibold text-gray-900"><%= project.name %></h3>
                            <%= if project.code do %>
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                                <%= project.code %>
                              </span>
                            <% end %>

                            <%!-- Status Badge --%>
                            <%= case project_status(project) do %>
                              <% :active -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                  Active
                                </span>
                              <% :upcoming -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                  Upcoming
                                </span>
                              <% :completed -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                  Completed
                                </span>
                              <% :inactive -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                  Inactive
                                </span>
                            <% end %>
                          </div>

                          <%= if project.description do %>
                            <p class="text-sm text-gray-600 mb-3"><%= project.description %></p>
                          <% end %>

                          <div class="flex items-center gap-6 text-sm text-gray-600">
                            <%= if Ecto.assoc_loaded?(project.supervisor) && project.supervisor do %>
                              <div class="flex items-center gap-1.5">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                                </svg>
                                <span><%= project.supervisor.username || project.supervisor.email %></span>
                              </div>
                            <% end %>

                            <div class="flex items-center gap-1.5">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                              </svg>
                              <span><%= length(project.attachees) %> Attachees</span>
                            </div>

                            <%= if project.starts_on do %>
                              <div class="flex items-center gap-1.5">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                                </svg>
                                <span><%= Calendar.strftime(project.starts_on, "%b %d, %Y") %></span>
                              </div>
                            <% end %>
                          </div>
                        </div>

                        <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                        </svg>
                      </div>
                    </.link>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
