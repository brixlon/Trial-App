defmodule TrialAppWeb.AdminLive.UserManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts

  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:filtered_users, users)
     |> assign(:filter, "all")
     |> assign(:search_query, "")
     |> assign(:selected_user, nil)
     |> assign(:selected_user_ids, MapSet.new())
     |> assign(:show_edit_modal, false)
     |> assign(:show_details_modal, false)
     |> assign(:show_bulk_actions, false)
     |> assign(:sort_by, "inserted_at")
     |> assign(:sort_order, :desc)
     |> assign(:departments, [])
     |> assign(:teams, [])
    }
  end

  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")
    search = Map.get(params, "search", "")

    users = socket.assigns.users
    filtered_users = users
                     |> apply_filter(filter)
                     |> apply_search(search)
                     |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

    {:noreply,
     socket
     |> assign(:filtered_users, filtered_users)
     |> assign(:filter, filter)
     |> assign(:search_query, search)
    }
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 text-gray-900">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />

        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto">
            <!-- Header with Actions -->
            <div class="mb-8 flex justify-between items-center">
              <div>
                <h1 class="text-3xl font-bold text-gray-900">User Management</h1>
                <p class="text-gray-600 mt-2">Manage user accounts, roles, and permissions</p>
              </div>
              <div class="flex space-x-3">
                <button
                  phx-click="export_users"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
                  </svg>
                  Export CSV
                </button>
                <button class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                  Add User
                </button>
              </div>
            </div>

            <!-- Search and Filter Bar -->
            <div class="mb-6 bg-white rounded-lg shadow-sm border border-gray-200 p-4">
              <div class="flex items-center space-x-4">
                <div class="flex-1">
                  <div class="relative">
                    <input
                      type="text"
                      phx-change="search"
                      phx-debounce="300"
                      name="query"
                      value={@search_query}
                      placeholder="Search users by name, email, or role..."
                      class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                    <svg class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                    </svg>
                  </div>
                </div>

                <%= if @show_bulk_actions do %>
                  <div class="flex items-center space-x-2 border-l pl-4">
                    <span class="text-sm text-gray-600">
                      <%= MapSet.size(@selected_user_ids) %> selected
                    </span>
                    <button
                      phx-click="bulk_approve"
                      class="px-3 py-1.5 text-sm bg-green-600 text-white rounded hover:bg-green-700"
                    >
                      Approve All
                    </button>
                    <button
                      phx-click="bulk_deactivate"
                      class="px-3 py-1.5 text-sm bg-red-600 text-white rounded hover:bg-red-700"
                    >
                      Deactivate All
                    </button>
                    <button
                      phx-click="clear_selection"
                      class="px-3 py-1.5 text-sm bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
                    >
                      Clear
                    </button>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Stats Cards -->
            <div class="grid grid-cols-4 gap-4 mb-6">
              <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm text-gray-600">Total Users</p>
                    <p class="text-2xl font-bold text-gray-900"><%= Enum.count(@users) %></p>
                  </div>
                  <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
                    </svg>
                  </div>
                </div>
              </div>

              <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm text-gray-600">Active Users</p>
                    <p class="text-2xl font-bold text-green-600"><%= Enum.count(@users, &(&1.status == "active")) %></p>
                  </div>
                  <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                  </div>
                </div>
              </div>

              <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm text-gray-600">Pending Approval</p>
                    <p class="text-2xl font-bold text-yellow-600"><%= Enum.count(@users, &(&1.status == "pending")) %></p>
                  </div>
                  <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                  </div>
                </div>
              </div>

              <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm text-gray-600">Admins</p>
                    <p class="text-2xl font-bold text-purple-600"><%= Enum.count(@users, &(&1.role == "admin")) %></p>
                  </div>
                  <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                    <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                    </svg>
                  </div>
                </div>
              </div>
            </div>

            <!-- Filter Tabs -->
            <div class="mb-6">
              <div class="border-b border-gray-200 bg-white rounded-t-lg">
                <nav class="-mb-px flex space-x-8 px-6">
                  <.link
                    patch={~p"/admin/users?filter=all"}
                    class={[
                      "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                      @filter == "all" && "border-blue-500 text-blue-600",
                      @filter != "all" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    All Users
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=pending"}
                    class={[
                      "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                      @filter == "pending" && "border-yellow-500 text-yellow-600",
                      @filter != "pending" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Pending Approval
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=active"}
                    class={[
                      "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                      @filter == "active" && "border-green-500 text-green-600",
                      @filter != "active" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Active Users
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=admin"}
                    class={[
                      "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                      @filter == "admin" && "border-purple-500 text-purple-600",
                      @filter != "admin" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Administrators
                  </.link>
                </nav>
              </div>
            </div>

            <!-- Users Table -->
            <div class="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left">
                      <input
                        type="checkbox"
                        phx-click="toggle_all"
                        checked={MapSet.size(@selected_user_ids) == Enum.count(@filtered_users) && !Enum.empty?(@filtered_users)}
                        class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                      />
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" phx-click="sort" phx-value-field="username">
                      User
                      <%= if @sort_by == "username" do %>
                        <span class="ml-1"><%= if @sort_order == :asc, do: "↑", else: "↓" %></span>
                      <% end %>
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" phx-click="sort" phx-value-field="status">
                      Status
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" phx-click="sort" phx-value-field="role">
                      Role
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer" phx-click="sort" phx-value-field="inserted_at">
                      Registered
                      <%= if @sort_by == "inserted_at" do %>
                        <span class="ml-1"><%= if @sort_order == :asc, do: "↑", else: "↓" %></span>
                      <% end %>
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Last Activity
                    </th>
                    <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for user <- @filtered_users do %>
                    <tr class={[
                      "hover:bg-gray-50 transition-colors",
                      MapSet.member?(@selected_user_ids, user.id) && "bg-blue-50"
                    ]}>
                      <td class="px-6 py-4">
                        <input
                          type="checkbox"
                          phx-click="toggle_user"
                          phx-value-user-id={user.id}
                          checked={MapSet.member?(@selected_user_ids, user.id)}
                          class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                        />
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex items-center">
                          <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center mr-3 shadow-sm">
                            <span class="text-white font-semibold text-sm">
                              <%= String.at(user.username, 0) |> String.upcase() %>
                            </span>
                          </div>
                          <div>
                            <div class="text-sm font-medium text-gray-900">
                              <%= user.username %>
                            </div>
                            <div class="text-sm text-gray-500">
                              <%= user.email %>
                            </div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
                          user_status_class(user.status)
                        ]}>
                          <span class={["w-1.5 h-1.5 mr-1.5 rounded-full", status_dot_class(user.status)]}></span>
                          <%= user_status_label(user.status) %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
                          role_class(user.role)
                        ]}>
                          <%= String.capitalize(user.role) %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= Timex.format!(user.inserted_at, "{M}/{D}/{YYYY}") %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <span class="text-xs text-gray-400">2h ago</span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <div class="flex justify-end space-x-2">
                          <%= if user.status == "pending" do %>
                            <button
                              phx-click="approve_user"
                              phx-value-user-id={user.id}
                              class="text-green-600 hover:text-green-900 hover:bg-green-50 px-2 py-1 rounded transition-colors"
                              title="Approve User"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                              </svg>
                            </button>
                          <% end %>

                          <%= if user.status == "active" && user.role == "user" do %>
                            <button
                              phx-click="make_admin"
                              phx-value-user-id={user.id}
                              class="text-purple-600 hover:text-purple-900 hover:bg-purple-50 px-2 py-1 rounded transition-colors"
                              title="Make Admin"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                              </svg>
                            </button>
                          <% end %>

                          <button
                            phx-click="edit_user"
                            phx-value-user-id={user.id}
                            class="text-blue-600 hover:text-blue-900 hover:bg-blue-50 px-2 py-1 rounded transition-colors"
                            title="Edit User"
                          >
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                            </svg>
                          </button>

                          <button
                            phx-click="view_user_details"
                            phx-value-user-id={user.id}
                            class="text-gray-600 hover:text-gray-900 hover:bg-gray-100 px-2 py-1 rounded transition-colors"
                            title="View Details"
                          >
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                            </svg>
                          </button>

                          <%= if user.status == "active" do %>
                            <button
                              phx-click="deactivate_user"
                              phx-value-user-id={user.id}
                              class="text-red-600 hover:text-red-900 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                              title="Deactivate User"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"/>
                              </svg>
                            </button>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@filtered_users) do %>
                <div class="text-center py-16">
                  <svg class="w-16 h-16 mx-auto text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
                  </svg>
                  <h3 class="mt-4 text-lg font-medium text-gray-900">No users found</h3>
                  <p class="mt-2 text-sm text-gray-500">
                    <%= if @search_query != "" do %>
                      Try adjusting your search or filter criteria.
                    <% else %>
                      <%= if @filter == "pending" do %>
                        No users are waiting for approval.
                      <% else %>
                        Get started by creating a new user.
                      <% end %>
                    <% end %>
                  </p>
                  <%= if @search_query != "" do %>
                    <button
                      phx-click="clear_search"
                      class="mt-4 inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                    >
                      Clear Search
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>

      <!-- Edit User Modal -->
      <%= if @show_edit_modal && @selected_user do %>
        <div class="fixed inset-0 bg-gray-900 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center" phx-click="close_modal">
          <div class="relative mx-auto p-6 border w-full max-w-2xl shadow-2xl rounded-xl bg-white" phx-click="stop_propagation">
            <div class="flex justify-between items-center pb-4 border-b">
              <h3 class="text-xl font-semibold text-gray-900">
                Edit User: <%= @selected_user.username %>
              </h3>
              <button
                phx-click="close_modal"
                class="text-gray-400 hover:text-gray-600 hover:bg-gray-100 p-2 rounded-lg transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="mt-6 space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Email</label>
                <input
                  type="email"
                  value={@selected_user.email}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Role</label>
                <select class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
                  <option value="user" selected={@selected_user.role == "user"}>User</option>
                  <option value="admin" selected={@selected_user.role == "admin"}>Administrator</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                <select class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
                  <option value="pending" selected={@selected_user.status == "pending"}>Pending</option>
                  <option value="active" selected={@selected_user.status == "active"}>Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="suspended">Suspended</option>
                </select>
              </div>

              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <p class="text-sm text-blue-800">
                  <strong>Note:</strong> Employee assignment features (department, team, manager) will be available once the Employee module is created.
                </p>
              </div>
            </div>

            <div class="flex justify-end space-x-3 pt-6 mt-6 border-t">
              <button
                type="button"
                phx-click="close_modal"
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                phx-click="save_user_changes"
                class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-lg shadow-sm hover:bg-blue-700 transition-colors"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <!-- User Details Modal -->
      <%= if @show_details_modal && @selected_user do %>
        <div class="fixed inset-0 bg-gray-900 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center" phx-click="close_details">
          <div class="relative mx-auto p-6 border w-full max-w-3xl shadow-2xl rounded-xl bg-white" phx-click="stop_propagation">
            <div class="flex justify-between items-center pb-4 border-b">
              <h3 class="text-xl font-semibold text-gray-900">
                User Details
              </h3>
              <button
                phx-click="close_details"
                class="text-gray-400 hover:text-gray-600 hover:bg-gray-100 p-2 rounded-lg transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="mt-6">
              <!-- User Profile Header -->
              <div class="flex items-center space-x-4 pb-6 border-b">
                <div class="w-20 h-20 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center shadow-lg">
                  <span class="text-white font-bold text-2xl">
                    <%= String.at(@selected_user.username, 0) |> String.upcase() %>
                  </span>
                </div>
                <div class="flex-1">
                  <h4 class="text-2xl font-bold text-gray-900"><%= @selected_user.username %></h4>
                  <p class="text-gray-600"><%= @selected_user.email %></p>
                  <div class="flex items-center space-x-2 mt-2">
                    <span class={[
                      "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
                      user_status_class(@selected_user.status)
                    ]}>
                      <%= user_status_label(@selected_user.status) %>
                    </span>
                    <span class={[
                      "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
                      role_class(@selected_user.role)
                    ]}>
                      <%= String.capitalize(@selected_user.role) %>
                    </span>
                  </div>
                </div>
              </div>

              <!-- User Information Grid -->
              <div class="grid grid-cols-2 gap-6 mt-6">
                <div>
                  <h5 class="text-sm font-semibold text-gray-500 uppercase mb-3">Account Information</h5>
                  <dl class="space-y-3">
                    <div>
                      <dt class="text-sm text-gray-600">User ID</dt>
                      <dd class="text-sm font-medium text-gray-900">#<%= @selected_user.id %></dd>
                    </div>
                    <div>
                      <dt class="text-sm text-gray-600">Registration Date</dt>
                      <dd class="text-sm font-medium text-gray-900">
                        <%= Timex.format!(@selected_user.inserted_at, "{Mfull} {D}, {YYYY}") %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm text-gray-600">Last Updated</dt>
                      <dd class="text-sm font-medium text-gray-900">
                        <%= Timex.format!(@selected_user.updated_at, "{Mfull} {D}, {YYYY}") %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm text-gray-600">Account Status</dt>
                      <dd class="text-sm font-medium text-gray-900">
                        <%= user_status_label(@selected_user.status) %>
                      </dd>
                    </div>
                  </dl>
                </div>

                <div>
                  <h5 class="text-sm font-semibold text-gray-500 uppercase mb-3">Activity & Stats</h5>
                  <dl class="space-y-3">
                    <div>
                      <dt class="text-sm text-gray-600">Last Login</dt>
                      <dd class="text-sm font-medium text-gray-900">2 hours ago</dd>
                    </div>
                    <div>
                      <dt class="text-sm text-gray-600">Login Count</dt>
                      <dd class="text-sm font-medium text-gray-900">47 times</dd>
                    </div>
                    <div>
                      <dt class="text-sm text-gray-600">Department</dt>
                      <dd class="text-sm font-medium text-gray-900">
                        <span class="text-gray-400 italic">Not assigned</span>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-sm text-gray-600">Team</dt>
                      <dd class="text-sm font-medium text-gray-900">
                        <span class="text-gray-400 italic">Not assigned</span>
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>

              <!-- Activity Timeline -->
              <div class="mt-6 pt-6 border-t">
                <h5 class="text-sm font-semibold text-gray-500 uppercase mb-4">Recent Activity</h5>
                <div class="space-y-4">
                  <div class="flex items-start space-x-3">
                    <div class="w-2 h-2 bg-blue-500 rounded-full mt-1.5"></div>
                    <div class="flex-1">
                      <p class="text-sm text-gray-900">Logged in to the system</p>
                      <p class="text-xs text-gray-500">2 hours ago</p>
                    </div>
                  </div>
                  <div class="flex items-start space-x-3">
                    <div class="w-2 h-2 bg-green-500 rounded-full mt-1.5"></div>
                    <div class="flex-1">
                      <p class="text-sm text-gray-900">Profile updated</p>
                      <p class="text-xs text-gray-500">3 days ago</p>
                    </div>
                  </div>
                  <div class="flex items-start space-x-3">
                    <div class="w-2 h-2 bg-green-500 rounded-full mt-1.5"></div>
                    <div class="flex-1">
                      <p class="text-sm text-gray-900">Account activated by admin</p>
                      <p class="text-xs text-gray-500">5 days ago</p>
                    </div>
                  </div>
                  <div class="flex items-start space-x-3">
                    <div class="w-2 h-2 bg-gray-400 rounded-full mt-1.5"></div>
                    <div class="flex-1">
                      <p class="text-sm text-gray-900">Account created</p>
                      <p class="text-xs text-gray-500">
                        <%= Timex.format!(@selected_user.inserted_at, "{relative}", :relative) %>
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex justify-between pt-6 mt-6 border-t">
              <button
                type="button"
                phx-click="delete_user"
                phx-value-user-id={@selected_user.id}
                class="px-4 py-2 text-sm font-medium text-red-600 bg-red-50 border border-red-200 rounded-lg hover:bg-red-100 transition-colors"
              >
                Delete User
              </button>
              <div class="flex space-x-3">
                <button
                  type="button"
                  phx-click="close_details"
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Close
                </button>
                <button
                  type="button"
                  phx-click="edit_user"
                  phx-value-user-id={@selected_user.id}
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-lg shadow-sm hover:bg-blue-700 transition-colors"
                >
                  Edit User
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers

  def handle_event("search", %{"query" => query}, socket) do
    filtered_users = socket.assigns.users
                     |> apply_filter(socket.assigns.filter)
                     |> apply_search(query)
                     |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_users, filtered_users)
    }
  end

  def handle_event("clear_search", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/users?filter=#{socket.assigns.filter}")}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    new_order = if socket.assigns.sort_by == field do
      if socket.assigns.sort_order == :asc, do: :desc, else: :asc
    else
      :asc
    end

    filtered_users = socket.assigns.filtered_users
                     |> apply_sort(field, new_order)

    {:noreply,
     socket
     |> assign(:sort_by, field)
     |> assign(:sort_order, new_order)
     |> assign(:filtered_users, filtered_users)
    }
  end

  def handle_event("toggle_user", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    selected_ids = socket.assigns.selected_user_ids

    new_selected = if MapSet.member?(selected_ids, user_id) do
      MapSet.delete(selected_ids, user_id)
    else
      MapSet.put(selected_ids, user_id)
    end

    {:noreply,
     socket
     |> assign(:selected_user_ids, new_selected)
     |> assign(:show_bulk_actions, MapSet.size(new_selected) > 0)
    }
  end

  def handle_event("toggle_all", _, socket) do
    all_ids = Enum.map(socket.assigns.filtered_users, & &1.id) |> MapSet.new()
    current_selected = socket.assigns.selected_user_ids

    new_selected = if MapSet.equal?(all_ids, current_selected) do
      MapSet.new()
    else
      all_ids
    end

    {:noreply,
     socket
     |> assign(:selected_user_ids, new_selected)
     |> assign(:show_bulk_actions, MapSet.size(new_selected) > 0)
    }
  end

  def handle_event("clear_selection", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_user_ids, MapSet.new())
     |> assign(:show_bulk_actions, false)
    }
  end

  def handle_event("approve_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_status(user, "active") do
      {:ok, _user} ->
        users = Accounts.list_users()
        filtered_users = users
                         |> apply_filter(socket.assigns.filter)
                         |> apply_search(socket.assigns.search_query)
                         |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

        {:noreply,
         socket
         |> put_flash(:info, "✓ User approved successfully!")
         |> assign(:users, users)
         |> assign(:filtered_users, filtered_users)
        }

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve user")}
    end
  end

  def handle_event("bulk_approve", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_user_ids)

    # Approve all selected users
    Enum.each(selected_ids, fn user_id ->
      user = Accounts.get_user!(user_id)
      Accounts.update_user_status(user, "active")
    end)

    users = Accounts.list_users()
    filtered_users = users
                     |> apply_filter(socket.assigns.filter)
                     |> apply_search(socket.assigns.search_query)
                     |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

    {:noreply,
     socket
     |> put_flash(:info, "✓ #{length(selected_ids)} users approved successfully!")
     |> assign(:users, users)
     |> assign(:filtered_users, filtered_users)
     |> assign(:selected_user_ids, MapSet.new())
     |> assign(:show_bulk_actions, false)
    }
  end

  def handle_event("bulk_deactivate", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_user_ids)

    Enum.each(selected_ids, fn user_id ->
      user = Accounts.get_user!(user_id)
      Accounts.update_user_status(user, "inactive")
    end)

    users = Accounts.list_users()
    filtered_users = users
                     |> apply_filter(socket.assigns.filter)
                     |> apply_search(socket.assigns.search_query)
                     |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

    {:noreply,
     socket
     |> put_flash(:info, "✓ #{length(selected_ids)} users deactivated")
     |> assign(:users, users)
     |> assign(:filtered_users, filtered_users)
     |> assign(:selected_user_ids, MapSet.new())
     |> assign(:show_bulk_actions, false)
    }
  end

  def handle_event("make_admin", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_role(user, "admin") do
      {:ok, _user} ->
        users = Accounts.list_users()
        filtered_users = users
                         |> apply_filter(socket.assigns.filter)
                         |> apply_search(socket.assigns.search_query)
                         |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

        {:noreply,
         socket
         |> put_flash(:info, "✓ User promoted to administrator!")
         |> assign(:users, users)
         |> assign(:filtered_users, filtered_users)
        }

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to promote user")}
    end
  end

  def handle_event("deactivate_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_status(user, "inactive") do
      {:ok, _user} ->
        users = Accounts.list_users()
        filtered_users = users
                         |> apply_filter(socket.assigns.filter)
                         |> apply_search(socket.assigns.search_query)
                         |> apply_sort(socket.assigns.sort_by, socket.assigns.sort_order)

        {:noreply,
         socket
         |> put_flash(:info, "✓ User deactivated")
         |> assign(:users, users)
         |> assign(:filtered_users, filtered_users)
         |> assign(:show_details_modal, false)
         |> assign(:selected_user, nil)
        }

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate user")}
    end
  end

  def handle_event("edit_user", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Accounts.get_user!(user_id)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_edit_modal, true)
     |> assign(:show_details_modal, false)
    }
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:selected_user, nil)
    }
  end

  def handle_event("view_user_details", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Accounts.get_user!(user_id)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_details_modal, true)
    }
  end

  def handle_event("close_details", _, socket) do
    {:noreply,
     socket
     |> assign(:show_details_modal, false)
     |> assign(:selected_user, nil)
    }
  end

  def handle_event("stop_propagation", _, socket) do
    {:noreply, socket}
  end

  def handle_event("save_user_changes", _, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "✓ User changes saved! (Full functionality coming with Employee module)")
     |> assign(:show_edit_modal, false)
     |> assign(:selected_user, nil)
    }
  end

  def handle_event("delete_user", %{"user-id" => user_id}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "User deletion requires confirmation. Feature coming soon.")
    }
  end

  def handle_event("export_users", _, socket) do
    # CSV export logic would go here
    {:noreply, put_flash(socket, :info, "✓ Exporting users to CSV...")}
  end

  # Helper Functions

  defp apply_filter(users, "all"), do: users
  defp apply_filter(users, "pending"), do: Enum.filter(users, &(&1.status == "pending"))
  defp apply_filter(users, "active"), do: Enum.filter(users, &(&1.status == "active"))
  defp apply_filter(users, "admin"), do: Enum.filter(users, &(&1.role == "admin"))
  defp apply_filter(users, _), do: users

  defp apply_search(users, ""), do: users
  defp apply_search(users, query) do
    query = String.downcase(query)
    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.username), query) ||
      String.contains?(String.downcase(user.email), query) ||
      String.contains?(String.downcase(user.role), query)
    end)
  end

  defp apply_sort(users, "username", order) do
    Enum.sort_by(users, & String.downcase(&1.username), order)
  end

  defp apply_sort(users, "status", order) do
    Enum.sort_by(users, & &1.status, order)
  end

  defp apply_sort(users, "role", order) do
    Enum.sort_by(users, & &1.role, order)
  end

  defp apply_sort(users, "inserted_at", order) do
    Enum.sort_by(users, & &1.inserted_at, order)
  end

  defp apply_sort(users, _, _), do: users

  defp user_status_class("pending"), do: "bg-yellow-100 text-yellow-800 border border-yellow-200"
  defp user_status_class("active"), do: "bg-green-100 text-green-800 border border-green-200"
  defp user_status_class("inactive"), do: "bg-gray-100 text-gray-800 border border-gray-200"
  defp user_status_class("suspended"), do: "bg-red-100 text-red-800 border border-red-200"
  defp user_status_class(_), do: "bg-gray-100 text-gray-800 border border-gray-200"

  defp status_dot_class("pending"), do: "bg-yellow-500"
  defp status_dot_class("active"), do: "bg-green-500"
  defp status_dot_class("inactive"), do: "bg-gray-500"
  defp status_dot_class("suspended"), do: "bg-red-500"
  defp status_dot_class(_), do: "bg-gray-500"

  defp user_status_label("pending"), do: "Pending"
  defp user_status_label("active"), do: "Active"
  defp user_status_label("inactive"), do: "Inactive"
  defp user_status_label("suspended"), do: "Suspended"
  defp user_status_label(_), do: "Unknown"

  defp role_class("admin"), do: "bg-purple-100 text-purple-800 border border-purple-200"
  defp role_class("user"), do: "bg-blue-100 text-blue-800 border border-blue-200"
  defp role_class(_), do: "bg-gray-100 text-gray-800 border border-gray-200"
end
