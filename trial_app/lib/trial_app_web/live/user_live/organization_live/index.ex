defmodule TrialAppWeb.OrganizationLive.Index do
  use TrialAppWeb, :live_view
  alias TrialAppWeb.SidebarComponent

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
      # User is active, show organization data
      # Mock data (replace with Organizations.list_organizations/0 later)
      organizations = [
        %{id: 1, name: "Tech Corp", description: "Tech company", email: "info@techcorp.com", phone: "123-456-7890", address: "123 Tech St"},
        %{id: 2, name: "Innovate Ltd", description: "Innovation firm", email: "info@innovate.com", phone: "987-654-3210", address: "456 Innovate Ave"}
      ]

      {:ok,
        socket
        |> assign(:user_status, "active")
        |> assign(:has_assignments, true)
        |> stream(:organizations, organizations)
      }
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={SidebarComponent} id="sidebar" socket={@socket} />

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
                    You'll gain access to organization information once your roles are assigned.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What you'll see after approval:</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Organization structure and details</li>
                      <li>• Access to departments and teams</li>
                      <li>• Company-wide information and resources</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Organizations View -->
              <h1 class="text-3xl font-bold text-gray-800 mb-8">Organizations</h1>

              <div class="mb-8 bg-gray-50 p-6 rounded-xl shadow-md">
                <h2 class="text-2xl font-semibold text-gray-700 mb-4">Manage Related</h2>
                <ul class="flex space-x-6">
                  <li>
                    <.link navigate={~p"/departments"} class="text-purple-600 hover:underline font-medium">
                      Departments
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/teams"} class="text-purple-600 hover:underline font-medium">
                      Teams
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/employees"} class="text-purple-600 hover:underline font-medium">
                      Employees
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/positions"} class="text-purple-600 hover:underline font-medium">
                      Positions
                    </.link>
                  </li>
                </ul>
              </div>

              <table class="w-full table-auto border-collapse">
                <thead>
                  <tr class="bg-gray-100">
                    <th class="p-4 text-left">Name</th>
                    <th class="p-4 text-left">Description</th>
                    <th class="p-4 text-left">Email</th>
                    <th class="p-4 text-left">Phone</th>
                    <th class="p-4 text-left">Address</th>
                    <th class="p-4 text-left">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {org_id, org} <- @streams.organizations do %>
                    <tr id={org_id} class="border-b hover:bg-gray-50 transition-colors">
                      <td class="p-4"><%= org.name %></td>
                      <td class="p-4"><%= org.description %></td>
                      <td class="p-4"><%= org.email %></td>
                      <td class="p-4"><%= org.phone %></td>
                      <td class="p-4"><%= org.address %></td>
                      <td class="p-4">
                        <button class="text-purple-600 hover:underline font-medium">Show</button>
                        <button class="text-purple-600 hover:underline ml-2 font-medium">Edit</button>
                        <button class="text-red-600 hover:underline ml-2 font-medium">Delete</button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <div class="mt-6">
                <button class="text-purple-600 hover:underline cursor-pointer font-medium">
                  New Organization
                </button>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
