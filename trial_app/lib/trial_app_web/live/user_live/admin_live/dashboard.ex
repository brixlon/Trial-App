defmodule TrialAppWeb.AdminLive.Dashboard do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts
  alias TrialApp.Organizations

  # Optional JS hook for auto-dismiss
  @impl true
  def mount(_params, _session, socket) do
    # Get user statistics
    total_users = Accounts.list_users() |> length()
    pending_users = Accounts.list_users_by_status("pending") |> length()
    active_users = Accounts.list_users_by_status("active") |> length()
    admin_users = Accounts.list_users_by_role("admin") |> length()

    # Get organization statistics
    organizations = Organizations.list_organizations()
    total_organizations = length(organizations)
    total_departments = Organizations.list_all_departments() |> length()

    total_teams =
      organizations
      |> Enum.map(fn org -> Organizations.count_teams_for_organization(org.id) end)
      |> Enum.sum()

    {:ok,
     socket
     |> assign(:total_users, total_users)
     |> assign(:pending_users, pending_users)
     |> assign(:active_users, active_users)
     |> assign(:admin_users, admin_users)
     |> assign(:total_organizations, total_organizations)
     |> assign(:total_departments, total_departments)
     |> assign(:total_teams, total_teams)
    }
  end

  # Flash color helper
  defp flash_color("info"), do: "bg-blue-100 text-blue-800"
  defp flash_color("success"), do: "bg-green-100 text-green-800"
  defp flash_color("error"), do: "bg-red-100 text-red-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />

        <main class="ml-64 w-full p-8">
          <div class="max-w-6xl mx-auto">

            <!-- Flash Notifications -->
            <div class="mb-4">
              <%= for {type, msg} <- @flash do %>
                <div class={"px-4 py-3 rounded mb-2 shadow #{flash_color(type)}"}>
                  <%= msg %>
                </div>
              <% end %>
            </div>

            <!-- Header -->
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
              <p class="text-gray-600 mt-2">Manage your organization and users</p>
            </div>

            <!-- Quick Stats - Users -->
            <div class="mb-6">
              <h2 class="text-lg font-semibold text-gray-700 mb-3">User Statistics</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-yellow-800 mb-2">Pending Users</h3>
                  <p class="text-3xl font-bold text-yellow-600"><%= @pending_users %></p>
                  <p class="text-yellow-600 text-sm">Waiting for approval</p>
                  <div class="mt-2">
                    <.link navigate={~p"/admin/users?filter=pending"} class="text-yellow-700 hover:text-yellow-800 text-sm font-medium">
                      Review now →
                    </.link>
                  </div>
                </div>

                <div class="bg-green-50 border border-green-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-green-800 mb-2">Active Users</h3>
                  <p class="text-3xl font-bold text-green-600"><%= @active_users %></p>
                  <p class="text-green-600 text-sm">Currently active</p>
                </div>

                <div class="bg-purple-50 border border-purple-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-purple-800 mb-2">Total Users</h3>
                  <p class="text-3xl font-bold text-purple-600"><%= @total_users %></p>
                  <p class="text-purple-600 text-sm">All system users</p>
                </div>

                <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-blue-800 mb-2">Admins</h3>
                  <p class="text-3xl font-bold text-blue-600"><%= @admin_users %></p>
                  <p class="text-blue-600 text-sm">Administrators</p>
                </div>
              </div>
            </div>

            <!-- Quick Stats - Organization -->
            <div class="mb-8">
              <h2 class="text-lg font-semibold text-gray-700 mb-3">Organization Statistics</h2>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="bg-indigo-50 border border-indigo-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-indigo-800 mb-2">Organizations</h3>
                  <p class="text-3xl font-bold text-indigo-600"><%= @total_organizations %></p>
                  <p class="text-indigo-600 text-sm">Total organizations</p>
                </div>

                <div class="bg-pink-50 border border-pink-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-pink-800 mb-2">Departments</h3>
                  <p class="text-3xl font-bold text-pink-600"><%= @total_departments %></p>
                  <p class="text-pink-600 text-sm">Total departments</p>
                </div>

                <div class="bg-teal-50 border border-teal-200 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-teal-800 mb-2">Teams</h3>
                  <p class="text-3xl font-bold text-teal-600"><%= @total_teams %></p>
                  <p class="text-teal-600 text-sm">Total teams</p>
                </div>
              </div>
            </div>

            <!-- Quick Actions -->
            <div class="bg-white border border-gray-200 rounded-lg p-6 mb-8">
              <h2 class="text-xl font-semibold text-gray-800 mb-4">Quick Actions</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <.link navigate={~p"/admin/users"} class="bg-blue-600 text-white px-4 py-3 rounded-lg text-center hover:bg-blue-700 transition flex flex-col items-center">
                  <svg class="w-6 h-6 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
                  </svg>
                  Manage Users
                </.link>
                <.link navigate={~p"/admin/organizations"} class="bg-green-600 text-white px-4 py-3 rounded-lg text-center hover:bg-green-700 transition flex flex-col items-center">
                  <svg class="w-6 h-6 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                  </svg>
                  Organizations
                </.link>
                <.link navigate={~p"/admin/departments"} class="bg-purple-600 text-white px-4 py-3 rounded-lg text-center hover:bg-purple-700 transition flex flex-col items-center">
                  <svg class="w-6 h-6 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                  </svg>
                  Departments
                </.link>
                <.link navigate={~p"/admin/teams"} class="bg-orange-600 text-white px-4 py-3 rounded-lg text-center hover:bg-orange-700 transition flex flex-col items-center">
                  <svg class="w-6 h-6 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                  </svg>
                  Teams
                </.link>
              </div>
            </div>

            <!-- Recent Activity -->
            <div class="bg-white border border-gray-200 rounded-lg p-6">
              <h2 class="text-xl font-semibold text-gray-800 mb-4">Recent Activity</h2>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                <p>No recent activity to display</p>
                <p class="text-sm mt-2">User approvals and system changes will appear here</p>
              </div>
            </div>

          </div>
        </main>
      </div>
    </div>
    """
  end
end
