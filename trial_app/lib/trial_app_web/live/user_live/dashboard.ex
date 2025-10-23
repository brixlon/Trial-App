defmodule TrialAppWeb.DashboardLive do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
        socket
        |> assign(:user_status, "pending")
        |> assign(:has_assignments, false)
        |> assign(:message, "Waiting for administrator assignment")
      }
    else
      # User is active, show normal dashboard
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
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />

        <main class="ml-64 w-full p-8">
          <div class="max-w-5xl mx-auto bg-white p-8">
            <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="text-center py-16">
                <div class="max-w-md mx-auto">
                  <div class="w-20 h-20 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6">
                    <svg class="w-10 h-10 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                  <h1 class="text-2xl font-bold text-gray-900 mb-4">Account Pending Approval</h1>
                  <p class="text-gray-600 mb-6">
                    Your registration is complete! An administrator will review your account
                    and assign your organizational roles shortly.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
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
              <div class="flex flex-col md:flex-row items-center justify-between mb-8 gap-4 border-b pb-4">
                <div>
                  <h1 class="text-3xl font-bold text-gray-900">
                    Welcome, <span class="text-blue-600"><%= @current_scope.user.username %></span>!
                  </h1>
                  <p class="text-gray-600 mt-1">You're successfully logged in.</p>
                </div>

                <.link
                  href="/users/logout"
                  method="delete"
                  class="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-all shadow-md"
                >
                  Logout
                </.link>
              </div>

              <!-- Overview Stats -->
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-6 mb-10">
                <div class="p-5 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition">
                  <h2 class="text-sm font-medium text-gray-600 mb-2">Organizations</h2>
                  <p class="text-3xl font-bold text-blue-600"><%= @org_count %></p>
                </div>
                <div class="p-5 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition">
                  <h2 class="text-sm font-medium text-gray-600 mb-2">Departments</h2>
                  <p class="text-3xl font-bold text-blue-600"><%= @dept_count %></p>
                </div>
                <div class="p-5 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition">
                  <h2 class="text-sm font-medium text-gray-600 mb-2">Teams</h2>
                  <p class="text-3xl font-bold text-blue-600"><%= @team_count %></p>
                </div>
                <div class="p-5 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition">
                  <h2 class="text-sm font-medium text-gray-600 mb-2">Employees</h2>
                  <p class="text-3xl font-bold text-blue-600"><%= @employee_count %></p>
                </div>
                <div class="p-5 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition">
                  <h2 class="text-sm font-medium text-gray-600 mb-2">Positions</h2>
                  <p class="text-3xl font-bold text-blue-600"><%= @position_count %></p>
                </div>
              </div>

              <!-- Account Information -->
              <div class="border border-gray-200 rounded-lg p-6 mb-10 shadow-sm">
                <h2 class="text-xl font-semibold text-gray-800 mb-4 border-b pb-2">Account Information</h2>
                <div class="space-y-3">
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-600 font-medium">Username:</span>
                    <span><%= @current_scope.user.username %></span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-600 font-medium">Email:</span>
                    <span><%= @current_scope.user.email %></span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-600 font-medium">Account ID:</span>
                    <span><%= @current_scope.user.id %></span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-32 text-gray-600 font-medium">Status:</span>
                    <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-semibold">
                      ✓ Active
                    </span>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div class="text-sm text-gray-500 text-center">
                <p>Powered by <span class="text-blue-600 font-semibold">Elixir</span> & Phoenix LiveView</p>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
