defmodule TrialAppWeb.AdminLive.TeamManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Organizations
  alias TrialApp.Teams.Team

  @impl true
  def mount(_params, _session, socket) do
    teams = Organizations.list_all_teams()
    departments = Organizations.list_all_departments()

    {:ok,
     socket
     |> assign(:teams, teams)
     |> assign(:departments, departments)
     |> assign(:show_form, false)
     |> assign(:form, to_form(Team.changeset(%Team{}, %{})))
     |> assign(:search_query, "")
     |> assign(:editing_id, nil)
     |> assign(:show_delete_modal, false)
     |> assign(:deleting_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-50">
      <!-- Sidebar -->
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <!-- Main Content -->
      <main class="flex-1 overflow-y-auto ml-64">
        <!-- Header Bar -->
        <div class="bg-white border-b border-gray-200 sticky top-0 z-10">
          <div class="px-8 py-6 flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900 flex items-center gap-3">
                <span class="text-4xl">🎯</span>
                Team Management
              </h1>
              <p class="text-gray-600 mt-2">Organize and manage your organization's teams</p>
            </div>
            <button
              phx-click="new_team"
              class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg hover:shadow-xl font-semibold"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Add Team
            </button>
          </div>
        </div>

        <!-- Content Area -->
        <div class="p-8">
          <div class="max-w-7xl mx-auto">
            <!-- Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
              <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-green-100 text-sm font-semibold">Total Teams</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@teams) %></p>
                  </div>
                  <div class="text-5xl opacity-50">🎯</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-blue-100 text-sm font-semibold">Active</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@teams) %></p>
                  </div>
                  <div class="text-5xl opacity-50">✅</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-purple-100 text-sm font-semibold">This Month</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@teams) %></p>
                  </div>
                  <div class="text-5xl opacity-50">📊</div>
                </div>
              </div>
            </div>

            <!-- Search Bar -->
            <div class="bg-white rounded-xl shadow-sm p-4 mb-6">
              <div class="relative">
                <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <input
                  type="text"
                  phx-change="search"
                  name="query"
                  value={@search_query}
                  placeholder="Search teams..."
                  class="w-full pl-10 pr-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 outline-none transition-all"
                />
              </div>
            </div>

            <!-- Teams Grid/List -->
            <%= if Enum.empty?(@teams) do %>
              <!-- Empty State -->
              <div class="bg-white rounded-2xl shadow-sm p-16 text-center">
                <div class="max-w-md mx-auto">
                  <div class="text-7xl mb-6">🎯</div>
                  <h3 class="text-2xl font-bold text-gray-900 mb-2">No Teams Yet</h3>
                  <p class="text-gray-600 mb-8">
                    Get started by creating your first team to organize your workforce.
                  </p>
                  <%= if Enum.empty?(@departments) do %>
                    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
                      <p class="text-yellow-800 text-sm mb-3">
                        ⚠️ You need to create departments before adding teams.
                      </p>
                      <.link
                        navigate={~p"/admin/departments"}
                        class="px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-all font-semibold text-sm"
                      >
                        Create Departments
                      </.link>
                    </div>
                  <% else %>
                    <button
                      phx-click="new_team"
                      class="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-green-600 to-emerald-600 text-white rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg font-semibold"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                      </svg>
                      Create First Team
                    </button>
                  <% end %>
                </div>
              </div>
            <% else %>
              <!-- Teams Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for team <- @teams do %>
                  <div class="bg-white rounded-xl shadow-sm hover:shadow-lg transition-all border-2 border-gray-100 hover:border-green-200 p-6 group">
                    <div class="flex items-start justify-between mb-4">
                      <div class="flex items-center gap-3">
                        <div class="w-12 h-12 bg-gradient-to-br from-green-500 to-emerald-500 rounded-xl flex items-center justify-center text-2xl">
                          🎯
                        </div>
                        <div>
                          <h3 class="font-bold text-lg text-gray-900 group-hover:text-green-600 transition-colors">
                            <%= team.name %>
                          </h3>
                          <span class="text-sm text-gray-500">Active</span>
                        </div>
                      </div>
                      <div class="flex gap-1">
                        <button
                          phx-click="edit_team"
                          phx-value-id={team.id}
                          class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                          title="Edit Team"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                          </svg>
                        </button>
                        <button
                          phx-click="show_delete_modal"
                          phx-value-id={team.id}
                          class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete Team"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                          </svg>
                        </button>
                      </div>
                    </div>

                    <p class="text-gray-600 text-sm mb-4 line-clamp-2">
                      <%= if team.description && team.description != "" do %>
                        <%= team.description %>
                      <% else %>
                        <span class="text-gray-400 italic">No description provided</span>
                      <% end %>
                    </p>

                    <div class="flex items-center gap-4 text-sm text-gray-500 pt-4 border-t border-gray-100">
                      <div class="flex items-center gap-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                        </svg>
                        <span><%= team.department.name %></span>
                      </div>
                      <div class="flex items-center gap-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
                        </svg>
                        <span><%= length(team.employees) %> Members</span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </main>

      <!-- Add/Edit Team Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl transform transition-all">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-green-500 to-emerald-500 rounded-xl flex items-center justify-center text-xl">
                  🎯
                </div>
                <h2 class="text-2xl font-bold text-gray-900">
                  <%= if @editing_id, do: "Edit Team", else: "Add New Team" %>
                </h2>
              </div>
              <button
                phx-click="hide_modal"
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Modal Body -->
            <.form for={@form} phx-submit="save_team" phx-change="validate_team" class="p-6 space-y-6">
              <.input
                field={@form[:name]}
                type="text"
                label="Team Name"
                placeholder="e.g., Engineering Team, Sales Team"
                required
              />

              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                placeholder="Brief description of this team's role and responsibilities..."
                rows="4"
              />
              <p class="mt-2 text-sm text-gray-500">Optional: Add a description to help identify this team</p>

              <.input
                field={@form[:department_id]}
                type="select"
                label="Department"
                options={Enum.map(@departments, &{&1.name, &1.id})}
                prompt="Select a department"
                required
              />

              <!-- Modal Footer -->
              <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="hide_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg font-semibold"
                >
                  <%= if @editing_id, do: "Update Team", else: "Create Team" %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Delete Confirmation Modal -->
      <%= if @show_delete_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-md shadow-2xl transform transition-all">
            <div class="p-6 text-center">
              <!-- Warning Icon -->
              <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.35 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                </svg>
              </div>

              <h3 class="text-xl font-bold text-gray-900 mb-2">Delete Team</h3>
              <p class="text-gray-600 mb-6">
                Are you sure you want to delete this team? This action cannot be undone.
              </p>

              <div class="flex justify-center gap-3">
                <button
                  phx-click="hide_delete_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  phx-click="confirm_delete"
                  phx-value-id={@deleting_id}
                  class="px-6 py-3 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-all shadow-lg font-semibold"
                >
                  Delete Team
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # --- Event Handlers ---
  @impl true
  def handle_event("new_team", _params, socket) do
    {:noreply, assign(socket,
      show_form: true,
      editing_id: nil,
      form: to_form(Team.changeset(%Team{}, %{}))
    )}
  end

  @impl true
  def handle_event("edit_team", %{"id" => id}, socket) do
    team = Organizations.get_team!(String.to_integer(id))
    {:noreply, assign(socket,
      show_form: true,
      editing_id: String.to_integer(id),
      form: to_form(Team.changeset(team, %{}))
    )}
  end

  @impl true
  def handle_event("hide_modal", _params, socket) do
    {:noreply, assign(socket,
      show_form: false,
      editing_id: nil,
      form: to_form(Team.changeset(%Team{}, %{}))
    )}
  end

  @impl true
  def handle_event("validate_team", %{"team" => team_params}, socket) do
    changeset = Team.changeset(%Team{}, team_params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save_team", %{"team" => team_params}, socket) do
    if socket.assigns.editing_id do
      team = Organizations.get_team!(socket.assigns.editing_id)
      case Organizations.update_team(team, team_params) do
        {:ok, _team} ->
          teams = Organizations.list_all_teams()
          {:noreply,
            socket
            |> assign(show_form: false, editing_id: nil, form: to_form(Team.changeset(%Team{}, %{})))
            |> assign(teams: teams)
            |> put_flash(:info, "✅ Team updated successfully!")
          }
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      case Organizations.create_team(team_params) do
        {:ok, _team} ->
          teams = Organizations.list_all_teams()
          {:noreply,
            socket
            |> assign(show_form: false, form: to_form(Team.changeset(%Team{}, %{})))
            |> assign(teams: teams)
            |> put_flash(:info, "✅ Team created successfully!")
          }
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  @impl true
  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket,
      show_delete_modal: true,
      deleting_id: String.to_integer(id)
    )}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket,
      show_delete_modal: false,
      deleting_id: nil
    )}
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    team = Organizations.get_team!(String.to_integer(id))
    case Organizations.delete_team(team) do
      {:ok, _team} ->
        teams = Organizations.list_all_teams()
        {:noreply,
          socket
          |> assign(teams: teams, show_delete_modal: false, deleting_id: nil)
          |> put_flash(:info, "🗑️ Team '#{team.name}' deleted successfully!")
        }
      {:error, _changeset} ->
        {:noreply,
          socket
          |> assign(show_delete_modal: false, deleting_id: nil)
          |> put_flash(:error, "Failed to delete team")
        }
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end
end
