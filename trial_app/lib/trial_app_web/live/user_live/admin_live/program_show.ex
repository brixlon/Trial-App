defmodule TrialAppWeb.AdminLive.ProgramShow do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialAppWeb.BreadcrumbComponent
  require Logger

  def mount(%{"id" => id}, _session, socket) do
    program_id = String.to_integer(id)
    Logger.info("=== Loading program #{program_id} ===")

    # Get program with basic info
    program = Eams.get_program!(program_id, %{preloads: [:organization, :department]})
    Logger.info("Program loaded: #{inspect(program.name)}")

    # Get projects - NOTE: Remove :attachees from preloads as it's not a direct association
    projects = Eams.list_projects_by_program(program.id, %{
      preloads: [:department, :organization, :supervisor]
    })
    Logger.info("Projects loaded: #{length(projects)}")

    # Get stats
    stats = Eams.get_program_stats(program.id)
    Logger.info("Stats: #{inspect(stats)}")

    # Get all attachees through each project
    all_attachees = load_program_attachees(projects)
    Logger.info("All attachees loaded: #{length(all_attachees)}")

    breadcrumbs = [
      %{label: "Programs", link: ~p"/admin/eams/programs"},
      %{label: program.name, link: nil}
    ]

    {:ok,
     socket
     |> assign(:program, program)
     |> assign(:projects, projects)
     |> assign(:all_attachees, all_attachees)
     |> assign(:stats, stats)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, program.name)
     |> assign(:selected_tab, "projects")
     |> assign(:search_projects, "")
     |> assign(:search_attachees, "")
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})}
  end

  # Load all unique attachees from all projects
  defp load_program_attachees(projects) do
    projects
    |> Enum.flat_map(fn project ->
      attachees = Eams.list_attachees_by_project(project.id)
      # Add project reference to each attachee
      Enum.map(attachees, &Map.put(&1, :project_id, project.id))
    end)
    |> Enum.uniq_by(& &1.id)
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  def handle_event("search_projects", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_projects, query)}
  end

  def handle_event("search_attachees", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_attachees, query)}
  end

  defp filtered_projects(projects, ""), do: projects
  defp filtered_projects(projects, query) do
    query = String.downcase(query)
    Enum.filter(projects, fn project ->
      String.contains?(String.downcase(project.name || ""), query) ||
      (project.code && String.contains?(String.downcase(project.code), query))
    end)
  end

  defp filtered_attachees(attachees, ""), do: attachees
  defp filtered_attachees(attachees, query) do
    query = String.downcase(query)
    Enum.filter(attachees, fn att ->
      user = att.user
      String.contains?(String.downcase(user.username || ""), query) ||
      String.contains?(String.downcase(user.email || ""), query)
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

  defp attachee_status(attachee) do
    today = Date.utc_today()
    cond do
      attachee.ends_on && Date.compare(attachee.ends_on, today) == :lt -> :completed
      attachee.starts_on && Date.compare(attachee.starts_on, today) == :gt -> :upcoming
      true -> :active
    end
  end

  # Helper to get attachee count for a project
  defp get_project_attachee_count(project_id) do
    project_id
    |> Eams.list_attachees_by_project()
    |> length()
  end

  def render(assigns) do
    ~H"""
      <div class="max-w-7xl mx-auto space-y-8">

      <!-- Breadcrumb -->
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

          <!-- Program Info -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
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

            <%= if @program.starts_on do %>
              <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
                <div>
                  <div class="text-xs text-purple-200">Start Date</div>
                  <div class="font-medium"><%= Calendar.strftime(@program.starts_on, "%b %d, %Y") %></div>
                </div>
              </div>
            <% end %>

            <%= if @program.ends_on do %>
              <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
                </svg>
                <div>
                  <div class="text-xs text-purple-200">End Date</div>
                  <div class="font-medium"><%= Calendar.strftime(@program.ends_on, "%b %d, %Y") %></div>
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

        <!-- Tabs -->
        <div class="bg-white rounded-xl shadow-md p-2 mb-6 inline-flex gap-1">
          <button
            phx-click="select_tab"
            phx-value-tab="projects"
            class={["px-6 py-2.5 rounded-lg font-medium transition-colors",
                    @selected_tab == "projects" && "bg-purple-600 text-white" || "text-gray-600 hover:bg-gray-100"]}
          >
            Projects (<%= length(@projects) %>)
          </button>
          <button
            phx-click="select_tab"
            phx-value-tab="attachees"
            class={["px-6 py-2.5 rounded-lg font-medium transition-colors",
                    @selected_tab == "attachees" && "bg-purple-600 text-white" || "text-gray-600 hover:bg-gray-100"]}
          >
            Attachees (<%= length(@all_attachees) %>)
          </button>
        </div>

        <!-- Tab Content -->
        <%= case @selected_tab do %>
          <% "projects" -> %>
            <!-- Search Bar for Projects -->
            <div class="bg-white shadow rounded-xl p-5 border border-gray-200 mb-4">
              <.form for={%{}} as={:search_projects} phx-change="search_projects">
                <div class="relative">
                  <.icon name="hero-magnifying-glass" class="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="text"
                    name="query"
                    value={@search_projects}
                    placeholder="Search projects by name, code, supervisor..."
                    class="w-full pl-12 pr-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-purple-500 focus:outline-none transition"
                    phx-debounce="300"
                  />
                </div>
              </.form>
            </div>

            <!-- Projects List -->
            <div class="space-y-4">
              <%= if filtered_projects(@projects, @search_projects) == [] do %>
                <div class="bg-white shadow rounded-xl border border-gray-200 p-16 text-center">
                  <div class="w-20 h-20 mx-auto mb-4 rounded-full bg-gray-100 flex items-center justify-center">
                    <.icon name="hero-folder-open" class="w-10 h-10 text-gray-400" />
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900">No projects found</h3>
                  <p class="text-gray-600 mt-1">
                    <%= if @search_projects == "", do: "This program doesn't have any projects yet", else: "Try adjusting your search" %>
                  </p>
                </div>
              <% else %>
                <div class="grid gap-4">
                  <%= for project <- filtered_projects(@projects, @search_projects) do %>
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
                                <%= get_project_attachee_count(project.id) %> Attachees
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

          <% "attachees" -> %>
            <!-- Search Bar for Attachees -->
            <div class="bg-white shadow rounded-xl p-5 border border-gray-200 mb-4">
              <.form for={%{}} as={:search_attachees} phx-change="search_attachees">
                <div class="relative">
                  <.icon name="hero-magnifying-glass" class="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="text"
                    name="query"
                    value={@search_attachees}
                    placeholder="Search attachees by name or email..."
                    class="w-full pl-12 pr-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-purple-500 focus:outline-none transition"
                    phx-debounce="300"
                  />
                </div>
              </.form>
            </div>

            <!-- Attachees List, Grouped by Project -->
            <div class="space-y-6">
              <%= if filtered_attachees(@all_attachees, @search_attachees) == [] do %>
                <div class="bg-white shadow rounded-xl border border-gray-200 p-16 text-center">
                  <div class="w-20 h-20 mx-auto mb-4 rounded-full bg-gray-100 flex items-center justify-center">
                    <.icon name="hero-user-group" class="w-10 h-10 text-gray-400" />
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900">No attachees found</h3>
                  <p class="text-gray-600 mt-1">
                    <%= if @search_attachees == "", do: "This program doesn't have any attachees yet", else: "Try adjusting your search" %>
                  </p>
                </div>
              <% else %>
                <% grouped_by_project = Enum.group_by(filtered_attachees(@all_attachees, @search_attachees), & &1.project_id) %>
                <%= for {project_id, attachees} <- grouped_by_project do %>
                  <% project = Enum.find(@projects, &(&1.id == project_id)) %>
                  <%= if project do %>
                    <div class="bg-white shadow rounded-xl border border-gray-200">
                      <div class="p-4 border-b border-gray-200 bg-gray-50">
                        <h3 class="text-lg font-semibold text-gray-900"><%= project.name %></h3>
                        <%= if project.department do %>
                          <p class="text-sm text-gray-600">Department: <%= project.department.name %></p>
                        <% end %>
                      </div>
                      <div class="p-4 space-y-4">
                        <%= for attachee <- attachees do %>
                          <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition">
                            <div class="flex items-center gap-3">
                              <div class="w-10 h-10 rounded-full bg-purple-100 text-purple-700 flex items-center justify-center font-bold">
                                <%= String.first(attachee.user.username || attachee.user.email) |> String.upcase() %>
                              </div>
                              <div>
                                <div class="font-medium text-gray-900"><%= attachee.user.username || attachee.user.email %></div>
                                <div class="text-sm text-gray-600"><%= attachee.user.email %></div>
                              </div>
                            </div>
                            <div class="flex items-center gap-4 text-sm text-gray-600">
                              <%= case attachee_status(attachee) do %>
                                <% :active -> %>
                                  <span class="inline-flex items-center gap-1 text-green-600">
                                    <.icon name="hero-check-circle" class="w-4 h-4" />
                                    Active
                                  </span>
                                <% :upcoming -> %>
                                  <span class="inline-flex items-center gap-1 text-blue-600">
                                    <.icon name="hero-clock" class="w-4 h-4" />
                                    Upcoming
                                  </span>
                                <% :completed -> %>
                                  <span class="inline-flex items-center gap-1 text-gray-600">
                                    <.icon name="hero-check-badge" class="w-4 h-4" />
                                    Completed
                                  </span>
                              <% end %>
                              <%= if attachee.starts_on do %>
                                <span>Starts: <%= Calendar.strftime(attachee.starts_on, "%b %d, %Y") %></span>
                              <% end %>
                              <%= if attachee.ends_on do %>
                                <span>Ends: <%= Calendar.strftime(attachee.ends_on, "%b %d, %Y") %></span>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              <% end %>
            </div>
        <% end %>
      </div>
    """
  end
end
