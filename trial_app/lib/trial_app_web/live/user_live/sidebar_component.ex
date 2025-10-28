defmodule TrialAppWeb.SidebarComponent do
  use TrialAppWeb, :live_component

  def render(assigns) do
    ~H"""
    <aside
      x-data="{ openAdmin: false }"
      class="w-64 bg-gradient-to-b from-purple-100 via-white to-purple-50 text-gray-800 h-screen fixed top-0 left-0 p-6 shadow-xl border-r border-purple-200"
    >
      <!-- Logo -->
      <div class="mb-10 text-center">
        <h1 class="text-3xl font-extrabold text-purple-700 tracking-tight">
          trial<span class="text-gray-900">app</span>
        </h1>
        <div class="h-1 w-12 mx-auto bg-purple-300 rounded-full mt-2"></div>
      </div>

      <!-- Navigation -->
      <nav>
        <ul class="space-y-3">
          <!-- Dashboard -->
          <li>
            <.link
              navigate={
                if @current_scope.user.role == "admin", do: ~p"/admin/dashboard", else: ~p"/dashboard"
              }
              class="block py-2.5 px-4 rounded-xl bg-white/50 hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium shadow-sm"
            >
              {if @current_scope.user.role == "admin", do: "Admin Dashboard", else: "Dashboard"}
            </.link>
          </li>

          <!-- Organizations -->
          <li>
            <.link
              navigate={~p"/organizations"}
              class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
            >
              Organizations
            </.link>
          </li>

          <%= if @current_scope.user.role != "admin" do %>
            <li>
              <.link
                navigate={~p"/employees"}
                class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
              >
                Employees
              </.link>
            </li>
            <li>
              <.link
                navigate={~p"/positions"}
                class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
              >
                Positions
              </.link>
            </li>
          <% end %>

          <!-- Admin Dropdown -->
          <%= if @current_scope.user.role == "admin" do %>
            <li>
              <button
                @click="openAdmin = !openAdmin"
                class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-purple-400 shadow-sm"
              >
                <span class="flex items-center gap-2">
                  <svg class="w-4 h-4 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 8v4l3 3"
                    />
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
                    class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                  >
                    User Management
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/employees"}
                    class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                  >
                    Employees
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/positions"}
                    class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                  >
                    Positions
                  </.link>
                </li>
              </ul>
            </li>
          <% end %>

          <!-- Settings -->
          <li>
            <.link
              navigate={~p"/users/settings"}
              class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
            >
              Settings
            </.link>
          </li>
        </ul>
      </nav>

      <!-- User Info -->
      <div class="absolute bottom-6 left-6 right-6 p-4 bg-white/80 rounded-xl border border-purple-200 shadow-md backdrop-blur-sm">
        <div class="flex items-center space-x-3">
          <div class="w-9 h-9 bg-purple-100 rounded-full flex items-center justify-center">
            <span class="text-purple-700 font-bold text-sm">
              {String.at(@current_scope.user.username, 0) |> String.upcase()}
            </span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-gray-800 truncate">
              {@current_scope.user.username}
            </p>
            <p class="text-xs text-purple-600 truncate">
              {if @current_scope.user.role == "admin", do: "Administrator", else: "User"}
            </p>
          </div>
        </div>
      </div>
    </aside>
    """
  end
end
