# lib/trial_app_web/live/organization_live/index.ex
defmodule TrialAppWeb.OrganizationLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock data for frontend-only
    organizations = [
      %{id: 1, name: "Tech Corp", email: "contact@techcorp.com"},
      %{id: 2, name: "Innovate Ltd", email: "info@innovate.com"}
    ]
    {:ok, stream(socket, :organizations, organizations)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Organizations")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />
        <main class="ml-64 w-full">
          <div class="max-w-4xl mx-auto">
            <div class="bg-white rounded-2xl shadow-2xl p-8">
              <h1 class="text-4xl font-bold text-gray-800 mb-6"><%= @page_title %></h1>

              <!-- Sub-Navigation -->
              <div class="mb-8 bg-gray-50 p-6 rounded-xl shadow-md">
                <h2 class="text-2xl font-bold text-gray-700 mb-4">Manage Related Items</h2>
                <ul class="flex flex-wrap gap-4">
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

              <!-- Organizations List -->
              <div class="bg-white p-6 rounded-xl shadow-md">
                <h2 class="text-2xl font-bold text-gray-700 mb-4">Organizations</h2>
                <table class="w-full border-collapse">
                  <thead>
                    <tr>
                      <th class="text-left p-2 text-gray-600">Name</th>
                      <th class="text-left p-2 text-gray-600">Email</th>
                      <th class="text-left p-2 text-gray-600">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {org_id, org} <- @streams.organizations do %>
                      <tr id={"organization-#{org.id}"} class="border-t">
                        <td class="p-2 text-gray-800"><%= org.name %></td>
                        <td class="p-2 text-gray-800"><%= org.email %></td>
                        <td class="p-2">
                          <span class="text-purple-600 hover:underline cursor-pointer">Show</span>
                          <span class="text-purple-600 hover:underline cursor-pointer ml-2">Edit</span>
                          <span class="text-red-600 hover:underline cursor-pointer ml-2">Delete</span>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="mt-6">
                <.link patch={~p"/organizations/new"} class="text-purple-600 hover:underline cursor-pointer font-medium">
                  New Organization
                </.link>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
