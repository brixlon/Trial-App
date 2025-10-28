defmodule TrialAppWeb.DashboardLive do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)
       |> assign(:message, "Waiting for administrator assignment")}
    else
      socket =
        assign(socket,
          current_scope: %{user: current_user},
          org_count: 5,
          dept_count: 12,
          team_count: 25,
          employee_count: 150,
          position_count: 30,
          user_status: "active",
          has_assignments: true
        )

      {:ok, socket}
    end
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
                  <p class="text-gray-500 mt-1">You’re successfully logged in.</p>
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
                    <svg class="w-6 h-6 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7h18M3 12h18M3 17h18"/></svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3">{@org_count}</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-indigo-500 to-blue-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Departments</h2>
                    <svg class="w-6 h-6 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6l4 2"/></svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3">{@dept_count}</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-blue-500 to-cyan-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Teams</h2>
                    <svg class="w-6 h-6 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a4 4 0 00-5-4H7a4 4 0 00-5 4v2h5"/></svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3">{@team_count}</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-cyan-500 to-teal-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Employees</h2>
                    <svg class="w-6 h-6 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.121 17.804A9 9 0 1118.878 6.195"/></svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3">{@employee_count}</p>
                </div>

                <div class="card transition-transform transform hover:scale-105 hover:shadow-2xl duration-300 bg-gradient-to-br from-teal-500 to-emerald-600 text-white rounded-xl p-6">
                  <div class="flex items-center justify-between">
                    <h2 class="text-sm font-medium text-white/80">Positions</h2>
                    <svg class="w-6 h-6 opacity-80" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 11c0-2 2-4 4-4m-8 8a4 4 0 014-4h8"/></svg>
                  </div>
                  <p class="text-4xl font-extrabold mt-3">{@position_count}</p>
                </div>
              </div>

              <!-- Account Information -->
              <div class="border border-gray-200 bg-white rounded-xl p-8 mb-12 shadow-md hover:shadow-lg transition duration-300">
                <h2 class="text-2xl font-semibold text-gray-800 mb-4 border-b pb-2">Account Information</h2>
                <div class="space-y-3">
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-500 font-medium uppercase text-sm">Username</span>
                    <span class="text-gray-800 font-semibold">{@current_scope.user.username}</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-500 font-medium uppercase text-sm">Email</span>
                    <span class="text-gray-800 font-semibold">{@current_scope.user.email}</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-500 font-medium uppercase text-sm">Account ID</span>
                    <span class="text-gray-800 font-semibold">{@current_scope.user.id}</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-500 font-medium uppercase text-sm">Status</span>
                    <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-semibold">
                      ✓ Active
                    </span>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div class="text-sm text-gray-500 text-center mt-10">
                <p>
                  Powered by <span class="text-purple-700 font-semibold">Elixir</span>
                  & Phoenix LiveView ⚡
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
