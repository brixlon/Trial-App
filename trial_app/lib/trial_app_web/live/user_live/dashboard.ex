# lib/trial_app_web/live/dashboard_live.ex
defmodule TrialAppWeb.DashboardLive do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock data for frontend-only
    socket = assign(socket,
      current_scope: %{user: %{username: "samuelmutinda", email: "samuel@example.com", id: 123}},
      org_count: 5,
      employee_count: 150
    )
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />
        <main class="ml-64 w-full">
          <div class="max-w-4xl mx-auto">
            <div class="bg-white rounded-2xl shadow-2xl p-8">
              <!-- Header -->
              <div class="flex flex-col md:flex-row items-center justify-between mb-8 gap-4">
                <div class="text-center md:text-left">
                  <h1 class="text-4xl font-bold text-gray-800 mb-2">
                    Welcome, <%= @current_scope.user.username %>!
                  </h1>
                  <p class="text-gray-600">You're successfully logged in!</p>
                </div>

                <.link
                  href="/users/logout"
                  method="delete"
                  class="px-6 py-3 bg-red-600 hover:bg-red-700 text-white font-semibold rounded-xl transition-all shadow-lg"
                >
                  🚪 Logout
                </.link>
              </div>

              <!-- Overview Cards -->
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                <div class="bg-white p-6 rounded-xl shadow-md">
                  <h2 class="text-2xl font-bold text-gray-800 mb-2">Organizations</h2>
                  <p class="text-3xl font-semibold text-purple-600"><%= @org_count %></p>
                </div>
                <div class="bg-white p-6 rounded-xl shadow-md">
                  <h2 class="text-2xl font-bold text-gray-800 mb-2">Employees</h2>
                  <p class="text-3xl font-semibold text-purple-600"><%= @employee_count %></p>
                </div>
              </div>

              <!-- Account Information -->
              <div class="bg-gray-50 rounded-xl p-6 mb-8">
                <h2 class="text-2xl font-bold text-gray-800 mb-4">Account Information</h2>
                <div class="space-y-3">
                  <div class="flex items-center gap-3">
                    <span class="text-gray-600 font-semibold w-32">Username:</span>
                    <span class="text-gray-800"><%= @current_scope.user.username %></span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="text-gray-600 font-semibold w-32">Email:</span>
                    <span class="text-gray-800"><%= @current_scope.user.email %></span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="text-gray-600 font-semibold w-32">Account ID:</span>
                    <span class="text-gray-800"><%= @current_scope.user.id %></span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="text-gray-600 font-semibold w-32">Status:</span>
                    <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-semibold">
                      ✓ Active
                    </span>
                  </div>
                </div>
              </div>

              <!-- Protected Info / Learning Section -->
              <div class="p-6 bg-blue-50 rounded-xl border-2 border-blue-200">
                <h3 class="text-lg font-bold text-blue-900 mb-2">🎓 Learning Authentication</h3>
                <p class="text-blue-800">
                  This is a protected page! Only logged-in users can see this content.
                  Try logging out and accessing this page - you'll be redirected to login!
                </p>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
