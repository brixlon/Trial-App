defmodule TrialAppWeb.TeamLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)}
    else
      # User is active, show team data
      # Mock data - in real app, this would come from database
      # For now, we'll simulate: total teams = 3, user's team = Frontend Team
      all_teams = [
        %{id: 1, name: "Frontend Team", description: "UI/UX development"},
        %{id: 2, name: "Backend Team", description: "Server-side logic"},
        %{id: 3, name: "DevOps Team", description: "Infrastructure and deployment"}
      ]

      # User's assigned team (in real app, this would come from user context)
      user_team = %{id: 1, name: "Frontend Team", description: "UI/UX development"}

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, true)
       |> assign(:total_teams, length(all_teams))
       |> assign(:user_team, user_team)
       |> stream(:teams, [user_team])}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />
        <main class="ml-64 p-8 w-full">
          <div class="max-w-6xl mx-auto bg-white rounded-2xl shadow-2xl p-8">
            <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="text-center py-16">
                <div class="max-w-md mx-auto">
                  <div class="w-20 h-20 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6">
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
                      >
                      </path>
                    </svg>
                  </div>
                  <h1 class="text-2xl font-bold text-gray-900 mb-4">Access Restricted</h1>
                  <p class="text-gray-600 mb-6">
                    Your account is pending administrator approval.
                    You'll gain access to team information once your roles are assigned.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What you'll see after approval:</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Your assigned team information</li>
                      <li>• Team members and collaboration tools</li>
                      <li>• Team-specific projects and resources</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Teams View -->
              <h1 class="text-3xl font-bold text-gray-800 mb-8">Teams</h1>

    <!-- Total Teams Count -->
              <div class="mb-6 p-4 bg-green-50 rounded-lg border border-green-200">
                <h2 class="text-lg font-semibold text-green-800">
                  Total Teams: <span class="text-2xl">{@total_teams}</span>
                </h2>
                <p class="text-green-600 text-sm mt-1">You are a member of 1 team</p>
              </div>

    <!-- User's Team -->
              <div class="mb-4">
                <h2 class="text-xl font-semibold text-gray-700 mb-4">Your Team</h2>
                <table class="w-full table-auto border-collapse">
                  <thead>
                    <tr class="bg-gray-100">
                      <th class="p-4 text-left">Name</th>
                      <th class="p-4 text-left">Description</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {team_id, team} <- @streams.teams do %>
                      <tr id={team_id} class="border-b hover:bg-gray-50">
                        <td class="p-4 font-medium text-gray-800">{team.name}</td>
                        <td class="p-4 text-gray-600">{team.description}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

    <!-- Note for regular users -->
              <div class="mt-6 p-4 bg-yellow-50 rounded-lg border border-yellow-200">
                <p class="text-yellow-700 text-sm">
                  <strong>Note:</strong>
                  As a regular user, you can only view the team you're assigned to.
                  Contact administrator for team changes.
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
