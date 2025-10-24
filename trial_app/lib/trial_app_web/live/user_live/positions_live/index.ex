defmodule TrialAppWeb.PositionLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock data
    positions = [
      %{id: 1, title: "Senior Developer", description: "Lead development", salary_range: "$100k - $150k"},
      %{id: 2, title: "HR Manager", description: "Manage HR", salary_range: "$80k - $120k"}
    ]
    {:ok, stream(socket, :positions, positions)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={SidebarComponent} id="sidebar" socket={@socket} />
        <main class="ml-64 p-8 w-full">
          <div class="max-w-6xl mx-auto bg-white rounded-2xl shadow-2xl p-8">
            <h1 class="text-3xl font-bold text-gray-800 mb-8">Positions</h1>
            <table class="w-full table-auto border-collapse">
              <thead>
                <tr class="bg-gray-100">
                  <th class="p-4 text-left">Title</th>
                  <th class="p-4 text-left">Description</th>
                  <th class="p-4 text-left">Salary Range</th>
                  <th class="p-4 text-left">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for {pos_id, pos} <- @streams.positions do %>
                  <tr id={pos_id} class="border-b">
                    <td class="p-4"><%= pos.title %></td>
                    <td class="p-4"><%= pos.description %></td>
                    <td class="p-4"><%= pos.salary_range %></td>
                    <td class="p-4">
                      <span class="text-purple-600 hover:underline cursor-pointer">Show</span>
                      <span class="text-purple-600 hover:underline cursor-pointer ml-2">Edit</span>
                      <span class="text-red-600 hover:underline cursor-pointer ml-2">Delete</span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <div class="mt-6">
              <span class="text-purple-600 hover:underline cursor-pointer font-medium">New Position</span>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
