defmodule TrialAppWeb.DashboardLive do
  use TrialAppWeb, :live_view
  alias TrialApp.Repo
  alias TrialApp.Accounts.User
  # Import your schema modules - adjust these based on your actual schemas
  # alias TrialApp.Organizations.Organization
  # alias TrialApp.Organizations.Department
  # alias TrialApp.Organizations.Team
  # alias TrialApp.Organizations.Employee
  # alias TrialApp.Organizations.Position

  import Ecto.Query

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)
       |> assign(:message, "Waiting for administrator assignment")}
    else
      # Fetch real data from database
      stats = fetch_dashboard_stats(current_user)
      user_details = fetch_user_details(current_user)
      recent_activity = fetch_recent_activity(current_user)

      socket =
        assign(socket,
          current_scope: %{user: current_user},
          org_count: stats.org_count,
          dept_count: stats.dept_count,
          team_count: stats.team_count,
          employee_count: stats.employee_count,
          position_count: stats.position_count,
          user_status: "active",
          has_assignments: true,
          user_details: user_details,
          recent_activity: recent_activity,
          stats: stats
        )

      {:ok, socket}
    end
  end

  # Fetch all dashboard statistics
  defp fetch_dashboard_stats(current_user) do
    %{
      org_count: count_organizations(current_user),
      dept_count: count_departments(current_user),
      team_count: count_teams(current_user),
      employee_count: count_employees(current_user),
      position_count: count_positions(current_user),
      total_users: count_total_users(),
      active_users: count_active_users(),
      pending_users: count_pending_users()
    }
  end

  # Count functions - adjust table names based on your schema
  defp count_organizations(user) do
    # If user is admin, count all organizations
    # Otherwise, count only organizations user has access to
    case user.role do
      "admin" ->
        # Repo.aggregate(Organization, :count, :id)
        # For now, using a direct query - adjust table name as needed
        Repo.one(from o in "organizations", select: count(o.id)) || 0

      _ ->
        # Count organizations user belongs to through assignments
        # This is a placeholder - adjust based on your actual schema
        query =
          from u in User,
            where: u.id == ^user.id,
            # join: assignments or relations here
            select: count(u.id)

        Repo.one(query) || 0
    end
  end

  defp count_departments(user) do
    case user.role do
      "admin" ->
        Repo.one(from d in "departments", select: count(d.id)) || 0

      _ ->
        # Count departments user has access to
        # Adjust based on your schema relationships
        Repo.one(
          from d in "departments",
            # Add appropriate joins and filters
            select: count(d.id)
        ) || 0
    end
  end

  defp count_teams(user) do
    case user.role do
      "admin" ->
        Repo.one(from t in "teams", select: count(t.id)) || 0

      _ ->
        # Count teams user belongs to
        Repo.one(
          from t in "teams",
            # Add joins for user_teams or team_members
            select: count(t.id)
        ) || 0
    end
  end

  defp count_employees(user) do
    case user.role do
      "admin" ->
        Repo.one(from e in "employees", select: count(e.id)) || 0

      _ ->
        # Count employees in user's organization/department
        Repo.one(
          from e in "employees",
            select: count(e.id)
        ) || 0
    end
  end

  defp count_positions(user) do
    case user.role do
      "admin" ->
        Repo.one(from p in "positions", select: count(p.id)) || 0

      _ ->
        Repo.one(
          from p in "positions",
            select: count(p.id)
        ) || 0
    end
  end

  defp count_total_users do
    Repo.one(from u in User, select: count(u.id)) || 0
  end

  defp count_active_users do
    Repo.one(from u in User, where: u.status == "active", select: count(u.id)) || 0
  end

  defp count_pending_users do
    Repo.one(from u in User, where: u.status == "pending", select: count(u.id)) || 0
  end

  # Fetch detailed user information with preloads
  defp fetch_user_details(current_user) do
    user =
      Repo.get!(User, current_user.id)
      # Add preloads based on your schema associations
      # |> Repo.preload([:organization, :department, :teams, :position])

    %{
      id: user.id,
      username: user.username,
      email: user.email,
      status: user.status,
      role: user.role,
      inserted_at: user.inserted_at,
      # organization: user.organization,
      # department: user.department,
      # teams: user.teams,
      # position: user.position
    }
  end

  # Fetch recent activity - customize based on your needs
  defp fetch_recent_activity(current_user) do
    # This is a placeholder - implement based on your activity tracking
    # Example: fetch recent logins, changes, assignments, etc.
    []
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-50 via-white to-indigo-50 text-gray-900">
      <div class="flex">
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <main class="ml-64 w-full px-10 py-8">
          <div class="max-w-7xl mx-auto bg-white/80 backdrop-blur-xl shadow-lg rounded-2xl p-10 border border-purple-100">
            <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="text-center py-20">
                <div class="max-w-md mx-auto">
                  <div class="w-20 h-20 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6 animate-pulse">
                    <svg
                      class="w-10 h-10 text-yellow-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      ></path>
                    </svg>
                  </div>
                  <h1 class="text-3xl font-bold text-gray-900 mb-4">Account Pending Approval</h1>
                  <p class="text-gray-600 mb-6">
                    Your registration is complete! An administrator will review your account
                    and assign your organizational roles shortly.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-xl p-5 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What happens next?</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Administrator will assign your department</li>
                      <li>• You'll be added to relevant teams</li>
                      <li>• Your position and access levels will be set</li>
                      <li>• You'll receive access to organizational data</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Dashboard -->
              <!-- Header -->
              <div class="flex flex-col md:flex-row items-center justify-between mb-10 gap-4 border-b border-purple-200 pb-5">
                <div>
                  <h1 class="text-4xl font-extrabold tracking-tight">
                    Welcome, <span class="text-purple-700"><%= @current_scope.user.username %></span>!
                  </h1>
                  <p class="text-gray-500 mt-1">
                    Last login: <%= Calendar.strftime(@current_scope.user.inserted_at, "%B %d, %Y") %>
                  </p>
                </div>

                <.link
                  href="/users/logout"
                  method="delete"
                  class="px-5 py-2.5 rounded-xl bg-gradient-to-r from-purple-500 to-indigo-600 text-white font-medium shadow-md hover:shadow-lg hover:scale-105 transform transition duration-200"
                >
                  Logout
                </.link>
              </div>

              <!-- Overview Stats -->
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-6 mb-12">
                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-purple-500 to-indigo-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Organizations</h2>
                    <svg
                      class="w-6 h-6 opacity-80"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                      />
                    </svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3"><%= @org_count %></p>
                  <p class="text-xs text-white/70 mt-2">Total organizations</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-indigo-500 to-blue-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Departments</h2>
                    <svg
                      class="w-6 h-6 opacity-80"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
                      />
                    </svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3"><%= @dept_count %></p>
                  <p class="text-xs text-white/70 mt-2">Active departments</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-blue-500 to-cyan-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Teams</h2>
                    <svg
                      class="w-6 h-6 opacity-80"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                      />
                    </svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3"><%= @team_count %></p>
                  <p class="text-xs text-white/70 mt-2">Collaborative teams</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-cyan-500 to-teal-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Employees</h2>
                    <svg
                      class="w-6 h-6 opacity-80"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
                      />
                    </svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3"><%= @employee_count %></p>
                  <p class="text-xs text-white/70 mt-2">Total workforce</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-teal-500 to-emerald-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Positions</h2>
                    <svg
                      class="w-6 h-6 opacity-80"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                      />
                    </svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3"><%= @position_count %></p>
                  <p class="text-xs text-white/70 mt-2">Job positions</p>
                </div>
              </div>

              <%= if @current_scope.user.role == "admin" do %>
                <!-- Admin Stats -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
                  <div class="bg-white border border-gray-200 rounded-xl p-6 shadow-sm hover:shadow-md transition duration-300">
                    <div class="flex items-center gap-3 mb-3">
                      <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                        <svg
                          class="w-6 h-6 text-blue-600"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
                          />
                        </svg>
                      </div>
                      <h3 class="text-lg font-semibold text-gray-800">Total Users</h3>
                    </div>
                    <p class="text-3xl font-bold text-gray-900"><%= @stats.total_users %></p>
                    <p class="text-sm text-gray-500 mt-1">Registered accounts</p>
                  </div>

                  <div class="bg-white border border-gray-200 rounded-xl p-6 shadow-sm hover:shadow-md transition duration-300">
                    <div class="flex items-center gap-3 mb-3">
                      <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                        <svg
                          class="w-6 h-6 text-green-600"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                      </div>
                      <h3 class="text-lg font-semibold text-gray-800">Active Users</h3>
                    </div>
                    <p class="text-3xl font-bold text-gray-900"><%= @stats.active_users %></p>
                    <p class="text-sm text-gray-500 mt-1">Currently active</p>
                  </div>

                  <div class="bg-white border border-gray-200 rounded-xl p-6 shadow-sm hover:shadow-md transition duration-300">
                    <div class="flex items-center gap-3 mb-3">
                      <div class="w-10 h-10 bg-yellow-100 rounded-lg flex items-center justify-center">
                        <svg
                          class="w-6 h-6 text-yellow-600"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                      </div>
                      <h3 class="text-lg font-semibold text-gray-800">Pending Users</h3>
                    </div>
                    <p class="text-3xl font-bold text-gray-900"><%= @stats.pending_users %></p>
                    <p class="text-sm text-gray-500 mt-1">Awaiting approval</p>
                  </div>
                </div>
              <% end %>

              <!-- Account Information -->
              <div class="border border-gray-200 bg-white rounded-xl p-8 mb-12 shadow-md hover:shadow-lg transition duration-300">
                <h2 class="text-2xl font-semibold text-gray-800 mb-6 border-b pb-3 flex items-center gap-2">
                  <svg
                    class="w-6 h-6 text-purple-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                    />
                  </svg>
                  Account Information
                </h2>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div class="space-y-4">
                    <div class="flex flex-col gap-1">
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        Username
                      </span>
                      <span class="text-gray-900 font-semibold text-lg">
                        <%= @current_scope.user.username %>
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        Email
                      </span>
                      <span class="text-gray-900 font-semibold text-lg">
                        <%= @current_scope.user.email %>
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        Role
                      </span>
                      <span class="inline-flex items-center gap-2">
                        <span class="px-3 py-1 bg-purple-100 text-purple-800 rounded-full text-sm font-semibold capitalize">
                          <%= @current_scope.user.role %>
                        </span>
                      </span>
                    </div>
                  </div>
                  <div class="space-y-4">
                    <div class="flex flex-col gap-1">
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        Account ID
                      </span>
                      <span class="text-gray-900 font-mono text-sm">
                        <%= @current_scope.user.id %>
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        Status
                      </span>
                      <span class="inline-flex items-center gap-2">
                        <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-semibold">
                          <span class="inline-block w-2 h-2 bg-green-500 rounded-full mr-1 animate-pulse"></span>
                          Active
                        </span>
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        Member Since
                      </span>
                      <span class="text-gray-900 font-semibold">
                        <%= Calendar.strftime(@current_scope.user.inserted_at, "%B %d, %Y") %>
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div class="text-sm text-gray-500 text-center mt-10 pt-6 border-t border-gray-200">
                <p class="flex items-center justify-center gap-2">
                  Powered by
                  <span class="text-purple-700 font-semibold">Elixir</span>
                  & Phoenix LiveView
                  <svg class="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                </p>
                <p class="text-xs text-gray-400 mt-2">
                  Dashboard data refreshed in real-time
                </p>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
