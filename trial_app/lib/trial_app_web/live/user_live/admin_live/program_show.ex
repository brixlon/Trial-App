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
  <Layouts.app flash={@flash} current_scope={@current_scope} page_title={@program.name}>
    <div class="max-w-7xl mx-auto space-y-8">

    <!-- Breadcrumb — restored! -->
      <div class="text-sm breadcrumbs">
        <BreadcrumbComponent.breadcrumb items={@breadcrumbs} />
      </div>
      <!-- Header Section -->
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold text-gray-800"><%= @program.name %></h1>
          <p class="text-gray-600 mt-1">
            <%= if @program.code, do: @program.code %>
            <%= if @program.code && @program.description, do: " • " %>
            <%= if @program.description, do: @program.description %>
          </p>
        </div>
        <div class="flex gap-3">
          <.link navigate={~p"/admin/eams/programs"} class="px-4 py-2 rounded-lg text-gray-700 border border-gray-300 hover:bg-gray-50 transition flex items-center gap-2">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back to Programs
          </.link>
        </div>
      </div>

      <!-- Hero Header Card -->
      <div class="bg-gradient-to-r from-purple-500 to-purple-500 rounded-2xl shadow-md p-4 text-white">
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-4xl font-bold mb-2"><%= @program.name %></h1>
            <%= if @program.code do %>
              <span class="inline-block px-4 py-1.5 bg-white/20 backdrop-blur-sm rounded-full text-sm font-semibold">
                <%= @program.code %>
              </span>
            <% end %>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
          <%= if Ecto.assoc_loaded?(@program.organization) && @program.organization do %>
            <div class="flex items-center gap-4 bg-white/10 backdrop-blur-sm rounded-xl p-5">
              <div class="w-12 h-12 rounded-xl bg-white/20 flex items-center justify-center">
                <.icon name="hero-building-office-2" class="w-7 h-7" />
              </div>
              <div>
                <p class="text-purple-200 text-sm">Organization</p>
                <p class="font-semibold text-lg"><%= @program.organization.name %></p>
              </div>
            </div>
          <% end %>

          <%= if Ecto.assoc_loaded?(@program.department) && @program.department do %>
            <div class="flex items-center gap-4 bg-white/10 backdrop-blur-sm rounded-xl p-5">
              <div class="w-12 h-12 rounded-xl bg-white/20 flex items-center justify-center">
                <.icon name="hero-user-group" class="w-7 h-7" />
              </div>
              <div>
                <p class="text-purple-200 text-sm">Department</p>
                <p class="font-semibold text-lg"><%= @program.department.name %></p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between mb-2">
            <div class="w-12 h-12 rounded-xl bg-purple-100 flex items-center justify-center">
              <.icon name="hero-folder" class="w-6 h-6 text-purple-600" />
            </div>
            <span class="text-2xl font-bold text-gray-900"><%= @stats.total_projects %></span>
          </div>
          <p class="text-sm text-gray-600">Total Projects</p>
        </div>

        <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between mb-2">
            <div class="w-12 h-12 rounded-xl bg-green-100 flex items-center justify-center">
              <.icon name="hero-check-circle" class="w-6 h-6 text-green-600" />
            </div>
            <span class="text-2xl font-bold text-gray-900"><%= @stats.active_projects %></span>
          </div>
          <p class="text-sm text-gray-600">Active Projects</p>
        </div>

        <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between mb-2">
            <div class="w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center">
              <.icon name="hero-users" class="w-6 h-6 text-blue-600" />
            </div>
            <span class="text-2xl font-bold text-gray-900"><%= @stats.total_attachees %></span>
          </div>
          <p class="text-sm text-gray-600">Total Attachees</p>
        </div>

        <div class="bg-white shadow rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between mb-2">
            <div class="w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center">
              <.icon name="hero-user-group" class="w-6 h-6 text-amber-600" />
            </div>
            <span class="text-2xl font-bold text-gray-900"><%= @stats.active_attachees %></span>
          </div>
          <p class="text-sm text-gray-600">Active Attachees</p>
        </div>
      </div>

      <!-- Search Bar -->
      <div class="bg-white shadow rounded-xl p-5 border border-gray-200">
        <.form for={%{}} as={:search} phx-change="search">
          <div class="relative">
            <.icon name="hero-magnifying-glass" class="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search projects by name, code, supervisor..."
              class="w-full pl-12 pr-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-purple-500 focus:outline-none transition"
              phx-debounce="300"
            />
          </div>
        </.form>
      </div>

      <!-- Projects List (Card Style) -->
      <div class="space-y-4">
        <%= if filtered_projects(@projects, @search_query) == [] do %>
          <div class="bg-white shadow rounded-xl border border-gray-200 p-16 text-center">
            <div class="w-20 h-20 mx-auto mb-4 rounded-full bg-gray-100 flex items-center justify-center">
              <.icon name="hero-folder-open" class="w-10 h-10 text-gray-400" />
            </div>
            <h3 class="text-lg font-semibold text-gray-900">No projects found</h3>
            <p class="text-gray-600 mt-1">
              <%= if @search_query == "", do: "This program doesn't have any projects yet", else: "Try adjusting your search" %>
            </p>
          </div>
        <% else %>
          <div class="grid gap-4">
            <%= for project <- filtered_projects(@projects, @search_query) do %>
              <.link
                navigate={~p"/admin/eams/programs/#{@program.id}/projects/#{project.id}"}
                class="block bg-white shadow rounded-xl border border-gray-200 hover:shadow-lg hover:border-gray-300 transition-all"
              >
                <div class="p-6">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="flex items-center gap-3 mb-3">
                        <div class="w-12 h-12 rounded-xl bg-purple-100 flex items-center justify-center text-purple-700 font-bold text-lg">
                          <%= String.first(project.name) |> String.upcase() %>
                        </div>
                        <div>
                          <h3 class="text-lg font-semibold text-gray-900"><%= project.name %></h3>
                          <%= if project.code do %>
                            <span class="text-sm text-purple-700 font-medium"><%= project.code %></span>
                          <% end %>
                        </div>
                      </div>

                      <%= if project.description do %>
                        <p class="text-sm text-gray-600 mb-4 line-clamp-2"><%= project.description %></p>
                      <% end %>

                      <div class="flex flex-wrap items-center gap-6 text-sm text-gray-600">
                        <!-- Status -->
                        <%= case project_status(project) do %>
                          <% :active -> %>
                            <span class="inline-flex items-center gap-1.5">
                              <.icon name="hero-check-circle" class="w-4 h-4 text-green-600" />
                              <span class="font-medium text-green-800">Active</span>
                            </span>
                          <% :upcoming -> %>
                            <span class="inline-flex items-center gap-1.5 text-blue-800">
                              <.icon name="hero-clock" class="w-4 h-4 text-blue-600" />
                              Upcoming
                            </span>
                          <% :completed -> %>
                            <span class="inline-flex items-center gap-1.5 text-gray-600">
                              <.icon name="hero-check-badge" class="w-4 h-4" />
                              Completed
                            </span>
                          <% :inactive -> %>
                            <span class="inline-flex items-center gap-1.5 text-red-800">
                              <.icon name="hero-x-circle" class="w-4 h-4 text-red-600" />
                              Inactive
                            </span>
                        <% end %>

                        <!-- Supervisor -->
                        <%= if Ecto.assoc_loaded?(project.supervisor) && project.supervisor do %>
                          <span class="flex items-center gap-1.5">
                            <.icon name="hero-user" class="w-4 h-4" />
                            <%= project.supervisor.username || project.supervisor.email %>
                          </span>
                        <% end %>

                        <!-- Attachees Count -->
                        <span class="flex items-center gap-1.5">
                          <.icon name="hero-user-group" class="w-4 h-4" />
                          <%= length(project.attachees) %> Attachees
                        </span>

                        <!-- Start Date -->
                        <%= if project.starts_on do %>
                          <span class="flex items-center gap-1.5">
                            <.icon name="hero-calendar" class="w-4 h-4" />
                            <%= Calendar.strftime(project.starts_on, "%b %d, %Y") %>
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <div class="ml-6">
                      <.icon name="hero-chevron-right" class="w-6 h-6 text-gray-400" />
                    </div>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  </Layouts.app>
  """
end
end
