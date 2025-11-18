defmodule TrialAppWeb.AdminLive.ProjectShow do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialAppWeb.BreadcrumbComponent

  def mount(%{"program_id" => program_id, "id" => id}, _session, socket) do
    project = Eams.get_project_with_details(String.to_integer(id))
    program = Eams.get_program!(String.to_integer(program_id))
    attachees = Eams.list_attachees_by_project(project.id)
    stats = Eams.get_project_stats(project.id)

    # Get available attachees for adding to project
    all_attachees = Eams.list_attachees()
    available_attachees = Enum.reject(all_attachees, fn a ->
      Enum.any?(attachees, &(&1.id == a.id))
    end)

    breadcrumbs = [
      %{label: "Programs", link: ~p"/admin/eams/programs"},
      %{label: program.name, link: ~p"/admin/eams/programs/#{program.id}"},
      %{label: project.name, link: nil}
    ]

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:program, program)
     |> assign(:attachees, attachees)
     |> assign(:stats, stats)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, project.name)
     |> assign(:search_query, "")
     |> assign(:show_add_modal, false)
     |> assign(:available_attachees, available_attachees)
     |> assign(:selected_attachee_id, nil)
     |> assign(:add_role, "Intern")
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, true)}
  end

  def handle_event("close_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_modal, false)
     |> assign(:selected_attachee_id, nil)
     |> assign(:add_role, "Intern")}
  end

  def handle_event("select_attachee", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_attachee_id, String.to_integer(id))}
  end

  def handle_event("update_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, :add_role, role)}
  end

  def handle_event("add_attachee", _params, socket) do
    case socket.assigns.selected_attachee_id do
      nil ->
        {:noreply, put_flash(socket, :error, "Please select an attachee")}

      attachee_id ->
        case Eams.add_attachee_to_project(socket.assigns.project.id, attachee_id, %{
          role: socket.assigns.add_role,
          joined_at: Date.utc_today()
        }) do
          {:ok, _} ->
            # Refresh data
            attachees = Eams.list_attachees_by_project(socket.assigns.project.id)
            all_attachees = Eams.list_attachees()
            available_attachees = Enum.reject(all_attachees, fn a ->
              Enum.any?(attachees, &(&1.id == a.id))
            end)
            stats = Eams.get_project_stats(socket.assigns.project.id)

            {:noreply,
             socket
             |> assign(:attachees, attachees)
             |> assign(:available_attachees, available_attachees)
             |> assign(:stats, stats)
             |> assign(:show_add_modal, false)
             |> assign(:selected_attachee_id, nil)
             |> put_flash(:info, "Attachee added successfully")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to add attachee")}
        end
    end
  end

  def handle_event("remove_attachee", %{"id" => id}, socket) do
    attachee_id = String.to_integer(id)

    case Eams.remove_attachee_from_project(socket.assigns.project.id, attachee_id) do
      {:ok, _} ->
        attachees = Eams.list_attachees_by_project(socket.assigns.project.id)
        all_attachees = Eams.list_attachees()
        available_attachees = Enum.reject(all_attachees, fn a ->
          Enum.any?(attachees, &(&1.id == a.id))
        end)
        stats = Eams.get_project_stats(socket.assigns.project.id)

        {:noreply,
         socket
         |> assign(:attachees, attachees)
         |> assign(:available_attachees, available_attachees)
         |> assign(:stats, stats)
         |> put_flash(:info, "Attachee removed from project")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove attachee")}
    end
  end

  defp filtered_attachees(attachees, ""), do: attachees
  defp filtered_attachees(attachees, query) do
    query = String.downcase(query)
    Enum.filter(attachees, fn attachee ->
      user_name = if Ecto.assoc_loaded?(attachee.user) && attachee.user do
        attachee.user.username || attachee.user.email || ""
      else
        ""
      end
      String.contains?(String.downcase(user_name), query) ||
      String.contains?(String.downcase(attachee.position || ""), query)
    end)
  end

  defp attachee_status(attachee) do
    cond do
      attachee.status == "suspended" -> :suspended
      attachee.status == "completed" -> :completed
      attachee.ends_on && Date.compare(attachee.ends_on, Date.utc_today()) == :lt -> :completed
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

            <!-- Project Header -->
            <div class="bg-gradient-to-r from-indigo-600 to-purple-600 rounded-2xl shadow-xl p-8 text-white">
              <div class="flex items-start justify-between mb-4">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-2">
                    <h1 class="text-4xl font-bold"><%= @project.name %></h1>
                    <%= if @project.code do %>
                      <span class="inline-block px-3 py-1 bg-white/20 backdrop-blur-sm text-sm font-medium rounded-full">
                        <%= @project.code %>
                      </span>
                    <% end %>
                  </div>
                  <%= if @project.description do %>
                    <p class="text-purple-100 text-lg mt-2"><%= @project.description %></p>
                  <% end %>
                </div>
              </div>

              <!-- Project Info Grid -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-6">
                <%= if Ecto.assoc_loaded?(@project.supervisor) && @project.supervisor do %>
                  <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                    </svg>
                    <div>
                      <div class="text-xs text-purple-200">Supervisor</div>
                      <div class="font-medium"><%= @project.supervisor.username || @project.supervisor.email %></div>
                    </div>
                  </div>
                <% end %>

                <%= if @project.starts_on do %>
                  <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                    <div>
                      <div class="text-xs text-purple-200">Start Date</div>
                      <div class="font-medium"><%= Calendar.strftime(@project.starts_on, "%b %d, %Y") %></div>
                    </div>
                  </div>
                <% end %>

                <%= if @project.ends_on do %>
                  <div class="flex items-center gap-3 bg-white/10 backdrop-blur-sm rounded-lg p-3">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
                    </svg>
                    <div>
                      <div class="text-xs text-purple-200">End Date</div>
                      <div class="font-medium"><%= Calendar.strftime(@project.ends_on, "%b %d, %Y") %></div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Stats Overview -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-purple-500">
                <div class="text-sm font-medium text-gray-600">Total Attachees</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.total_attachees %></div>
              </div>
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-green-500">
                <div class="text-sm font-medium text-gray-600">Active Attachees</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.active_attachees %></div>
              </div>
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-blue-500">
                <div class="text-sm font-medium text-gray-600">Total Tasks</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.total_tasks %></div>
              </div>
              <div class="bg-white rounded-xl shadow-sm p-6 border-l-4 border-amber-500">
                <div class="text-sm font-medium text-gray-600">Completion Rate</div>
                <div class="text-3xl font-bold text-gray-900 mt-2"><%= @stats.completion_rate %>%</div>
              </div>
            </div>

            <!-- Actions & Search Bar -->
            <div class="flex items-center gap-4">
              <div class="flex-1">
                <form phx-change="search" class="relative">
                  <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                  </svg>
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search attachees..."
                    class="w-full pl-10 pr-4 py-2 bg-white border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 shadow-sm"
                  />
                </form>
              </div>
              <button
                phx-click="open_add_modal"
                class="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition shadow-sm"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                Add Attachee
              </button>
            </div>

            <!-- Attachees List -->
            <div class="bg-white rounded-xl shadow-sm overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200">
                <h2 class="text-xl font-bold text-gray-900">Project Attachees</h2>
                <p class="text-sm text-gray-600 mt-1">Click on an attachee to view their details, tasks, and evaluations</p>
              </div>

              <%= if filtered_attachees(@attachees, @search_query) == [] do %>
                <div class="p-12 text-center">
                  <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                  </svg>
                  <h3 class="text-lg font-medium text-gray-900 mb-2">No attachees found</h3>
                  <p class="text-gray-600 mb-4">Add attachees to this project to get started</p>
                  <button
                    phx-click="open_add_modal"
                    class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition"
                  >
                    Add Your First Attachee
                  </button>
                </div>
              <% else %>
                <div class="divide-y divide-gray-200">
                  <%= for attachee <- filtered_attachees(@attachees, @search_query) do %>
                    <div class="p-6 hover:bg-gray-50 transition-colors">
                      <div class="flex items-start justify-between">
                        <.link
                          navigate={~p"/admin/eams/programs/#{@program.id}/projects/#{@project.id}/attachees/#{attachee.id}"}
                          class="flex-1 group"
                        >
                          <div class="flex items-start gap-4">
                            <!-- Avatar -->
                            <div class="w-12 h-12 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white font-bold text-lg flex-shrink-0">
                              <%= if Ecto.assoc_loaded?(attachee.user) && attachee.user && attachee.user.username do %>
                                <%= String.first(attachee.user.username) |> String.upcase() %>
                              <% else %>
                                A
                              <% end %>
                            </div>

                            <div class="flex-1">
                              <div class="flex items-center gap-2 mb-1">
                                <h3 class="text-lg font-semibold text-gray-900 group-hover:text-purple-600 transition-colors">
                                  <%= if Ecto.assoc_loaded?(attachee.user) && attachee.user do %>
                                    <%= attachee.user.username || attachee.user.email %>
                                  <% else %>
                                    Attachee #<%= attachee.id %>
                                  <% end %>
                                </h3>

                                <%!-- Status Badge --%>
                                <%= case attachee_status(attachee) do %>
                                  <% :active -> %>
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                      Active
                                    </span>
                                  <% :suspended -> %>
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                                      Suspended
                                    </span>
                                  <% :completed -> %>
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                      Completed
                                    </span>
                                <% end %>
                              </div>

                              <p class="text-sm text-gray-600 mb-2"><%= attachee.position %></p>

                              <div class="flex items-center gap-6 text-sm text-gray-600">
                                <%= if attachee.starts_on do %>
                                  <div class="flex items-center gap-1.5">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                                    </svg>
                                    <span>Started: <%= Calendar.strftime(attachee.starts_on, "%b %d, %Y") %></span>
                                  </div>
                                <% end %>

                                <%= if Ecto.assoc_loaded?(attachee.department) && attachee.department do %>
                                  <div class="flex items-center gap-1.5">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                                    </svg>
                                    <span><%= attachee.department.name %></span>
                                  </div>
                                <% end %>
                              </div>
                            </div>
                          </div>
                        </.link>

                        <!-- Actions -->
                        <div class="flex items-center gap-2 ml-4">
                          <.link
                            navigate={~p"/admin/eams/programs/#{@program.id}/projects/#{@project.id}/attachees/#{attachee.id}"}
                            class="p-2 hover:bg-purple-50 rounded-lg text-purple-600 transition"
                            title="View Details"
                          >
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                            </svg>
                          </.link>

                          <button
                            phx-click="remove_attachee"
                            phx-value-id={attachee.id}
                            data-confirm="Remove this attachee from the project?"
                            class="p-2 hover:bg-red-50 rounded-lg text-red-600 transition"
                            title="Remove from Project"
                          >
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                            </svg>
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>
    </div>

    <%!-- Add Attachee Modal --%>
    <%= if @show_add_modal do %>
      <div class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
        <div class="bg-white rounded-2xl w-full max-w-2xl shadow-2xl">
          <!-- Modal Header -->
          <div class="flex items-center justify-between px-8 py-6 border-b border-gray-200">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Add Attachee to Project</h2>
              <p class="text-sm text-gray-500 mt-1">Select an attachee to add to this project</p>
            </div>
            <button phx-click="close_add_modal" class="p-2 hover:bg-gray-100 rounded-lg transition-colors">
              <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Modal Body -->
          <div class="px-8 py-6">
            <%= if @available_attachees == [] do %>
              <div class="text-center py-8">
                <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
                <p class="text-gray-600">All available attachees are already in this project</p>
              </div>
            <% else %>
              <div class="space-y-4">
                <!-- Role Input -->
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">Role in Project</label>
                  <input
                    type="text"
                    phx-change="update_role"
                    name="role"
                    value={@add_role}
                    placeholder="e.g., Intern, Junior Developer, etc."
                    class="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  />
                </div>

                <!-- Attachee Selection -->
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">Select Attachee</label>
                  <div class="max-h-64 overflow-y-auto border border-gray-300 rounded-lg divide-y">
                    <%= for attachee <- @available_attachees do %>
                      <label class={"flex items-center gap-3 p-3 hover:bg-gray-50 cursor-pointer transition #{if @selected_attachee_id == attachee.id, do: "bg-purple-50"}"}>
                        <input
                          type="radio"
                          name="attachee_id"
                          value={attachee.id}
                          phx-click="select_attachee"
                          phx-value-id={attachee.id}
                          checked={@selected_attachee_id == attachee.id}
                          class="w-4 h-4 text-purple-600"
                        />
                        <div class="flex-1">
                          <div class="font-medium text-gray-900">
                            <%= if Ecto.assoc_loaded?(attachee.user) && attachee.user do %>
                              <%= attachee.user.username || attachee.user.email %>
                            <% else %>
                              Attachee #<%= attachee.id %>
                            <% end %>
                          </div>
                          <div class="text-sm text-gray-600"><%= attachee.position %></div>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Modal Footer -->
          <%= if @available_attachees != [] do %>
            <div class="flex items-center justify-end gap-3 px-8 py-6 border-t border-gray-200 bg-gray-50 rounded-b-2xl">
              <button
                phx-click="close_add_modal"
                class="px-6 py-2.5 rounded-lg border-2 border-gray-300 text-gray-700 font-medium hover:bg-gray-100 transition-colors"
              >
                Cancel
              </button>
              <button
                phx-click="add_attachee"
                disabled={is_nil(@selected_attachee_id)}
                class={"px-6 py-2.5 rounded-lg font-medium transition-all #{if @selected_attachee_id, do: "bg-purple-600 text-white hover:bg-purple-700 shadow-lg shadow-purple-500/30", else: "bg-gray-300 text-gray-500 cursor-not-allowed"}"}
              >
                Add to Project
              </button>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end
end
