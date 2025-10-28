defmodule TrialAppWeb.SidebarComponent do
  use TrialAppWeb, :live_component

  def render(assigns) do
    # Safe default for current_scope
    current_scope = assigns[:current_scope] || %{user: %{role: "guest", username: "Guest"}}

    ~H"""
    <aside
      x-data="{ openOrganizations: false, openAdmin: false }"
      class="w-64 bg-gray-50 text-gray-800 h-screen fixed top-0 left-0 p-6 shadow-md border-r border-gray-200"
    >
      <!-- Logo -->
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-blue-600">
          trial<span class="text-gray-800">app</span>
        </h1>
      </div>

      <!-- Navigation -->
      <nav>
        <ul class="space-y-4">
          <!-- Dashboard -->
          <li>
            <.link
              navigate={if current_scope.user.role == "admin", do: ~p"/admin/dashboard", else: ~p"/dashboard"}
              class="block py-2 px-4 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors font-medium"
            >
              <%= if current_scope.user.role == "admin", do: "Admin Dashboard", else: "Dashboard" %>
            </.link>
          </li>

          <!-- Organizations (Static Link) -->
          <li>
            <.link
              navigate={~p"/organizations"}
              class="block py-2 px-4 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors font-medium"
            >
              Organizations
            </.link>
          </li>

          <!-- Admin Section (only for admins) -->
          <%= if current_scope.user.role == "admin" do %>
            <li>
              <button
                @click="openAdmin = !openAdmin"
                class="w-full text-left py-2 px-4 rounded hover:bg-red-50 hover:text-red-600 transition-colors font-medium flex justify-between items-center border-l-4 border-red-400"
              >
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                  Admin
                </span>
                <span x-text="openAdmin ? '▾' : '▸'"></span>
              </button>

              <ul
                x-show="openAdmin"
                x-transition
                class="ml-4 mt-2 space-y-2"
              >
                <li>
                  <.link
                    navigate={~p"/admin/users"}
                    class="block py-1 px-3 rounded hover:bg-red-50 hover:text-red-600 transition-colors text-sm"
                  >
                    User Management
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/organizations"}
                    class="block py-1 px-3 rounded hover:bg-red-50 hover:text-red-600 transition-colors text-sm"
                  >
                    Organizations
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/departments"}
                    class="block py-1 px-3 rounded hover:bg-red-50 hover:text-red-600 transition-colors text-sm"
                  >
                    Departments
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/teams"}
                    class="block py-1 px-3 rounded hover:bg-red-50 hover:text-red-600 transition-colors text-sm"
                  >
                    Teams
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/employees"}
                    class="block py-1 px-3 rounded hover:bg-red-50 hover:text-red-600 transition-colors text-sm"
                  >
                    Employees
                  </.link>
                </li>
              </ul>
            </li>
          <% end %>

          <!-- Organizations (Collapsible Section) -->
          <li>
            <button
              @click="openOrganizations = !openOrganizations"
              class="w-full text-left py-2 px-4 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors font-medium flex justify-between items-center"
            >
              <span>Organizations</span>
              <span x-text="openOrganizations ? '▾' : '▸'"></span>
            </button>

            <ul
              x-show="openOrganizations"
              x-transition
              class="ml-4 mt-2 space-y-2"
            >
              <li>
                <.link
                  navigate={~p"/departments"}
                  class="block py-1 px-3 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors text-sm"
                >
                  Departments
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/teams"}
                  class="block py-1 px-3 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors text-sm"
                >
                  Teams
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/employees"}
                  class="block py-1 px-3 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors text-sm"
                >
                  Employees
                </.link>
              </li>
            </ul>
          </li>

          <!-- Settings -->
          <li>
            <.link
              navigate={~p"/users/settings"}
              class="block py-2 px-4 rounded hover:bg-blue-50 hover:text-blue-600 transition-colors font-medium"
            >
              Settings
            </.link>
          </li>
        </ul>
      </nav>

      <!-- User Info -->
      <div class="absolute bottom-6 left-6 right-6 p-4 bg-white rounded-lg border border-gray-200">
        <div class="flex items-center space-x-3">
          <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
            <span class="text-blue-600 font-semibold text-sm">
              <%= current_scope.user.username |> String.at(0) |> String.upcase() %>
            </span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">
              <%= current_scope.user.username %>
            </p>
            <p class="text-xs text-gray-500 truncate">
              <%= if current_scope.user.role == "admin", do: "Administrator", else: "User" %>
            </p>
          </div>
        </div>
      </div>
    </aside>
    """
  end
end
