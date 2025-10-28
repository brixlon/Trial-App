defmodule TrialAppWeb.DepartmentLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
        socket
        |> assign(:user_status, "pending")
        |> assign(:has_assignments, false)
      }
    else
      # User is active, show department data
      # (Mock data for now)
      all_departments = [
        %{id: 1, name: "Engineering", description: "Software development"},
        %{id: 2, name: "HR", description: "Human resources"},
        %{id: 3, name: "Marketing", description: "Marketing and sales"},
        %{id: 4, name: "Finance", description: "Financial operations"}
      ]

      # User's assigned department (mock)
      user_department = %{id: 1, name: "Engineering", description: "Software development"}

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, true)
       |> assign(:total_departments, length(all_departments))
       |> assign(:user_department, user_department)
       |> stream(:departments, [user_department])}
    end
  end
<<<<<<< Updated upstream

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />
        <main class="ml-64 p-8 w-full">
          <div class="max-w-6xl mx-auto bg-white rounded-2xl shadow-2xl p-8">
            <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="text-center py-16">
                <div class="max-w-md mx-auto">
                  <div class="w-20 h-20 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6">
                    <svg class="w-10 h-10 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                  <h1 class="text-2xl font-bold text-gray-900 mb-4">Access Restricted</h1>
                  <p class="text-gray-600 mb-6">
                    Your account is pending administrator approval.
                    You'll gain access to department information once your roles are assigned.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What you'll see after approval:</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Your assigned department information</li>
                      <li>• Department-specific data and resources</li>
                      <li>• Team members in your department</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Departments View -->
              <h1 class="text-3xl font-bold text-gray-800 mb-8">Departments</h1>

              <!-- Total Departments Count -->
              <div class="mb-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
                <h2 class="text-lg font-semibold text-blue-800">
                  Total Departments: <span class="text-2xl"><%= @total_departments %></span>
                </h2>
                <p class="text-blue-600 text-sm mt-1">You have access to 1 department</p>
              </div>

              <!-- User's Department -->
              <div class="mb-4">
                <h2 class="text-xl font-semibold text-gray-700 mb-4">Your Department</h2>
                <table class="w-full table-auto border-collapse">
                  <thead>
                    <tr class="bg-gray-100">
                      <th class="p-4 text-left">Name</th>
                      <th class="p-4 text-left">Description</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {dept_id, dept} <- @streams.departments do %>
                      <tr id={dept_id} class="border-b hover:bg-gray-50">
                        <td class="p-4 font-medium text-gray-800"><%= dept.name %></td>
                        <td class="p-4 text-gray-600"><%= dept.description %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <!-- Note for regular users -->
              <div class="mt-6 p-4 bg-yellow-50 rounded-lg border border-yellow-200">
                <p class="text-yellow-700 text-sm">
                  <strong>Note:</strong> As a regular user, you can only view the department you're assigned to.
                  Contact administrator for department changes.
                </p>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end
=======
>>>>>>> Stashed changes
end
