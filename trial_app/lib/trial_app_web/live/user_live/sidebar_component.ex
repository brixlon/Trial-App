defmodule TrialAppWeb.SidebarComponent do
  use TrialAppWeb, :live_component

  def mount(socket) do
    {:ok,
     socket
     |> assign(:sidebar_open, true)
     |> assign(:admin_open, false)
     |> assign(:eams_open, false)
     |> assign(:show_role_switcher, false)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  def handle_event("toggle_admin", _params, socket) do
    {:noreply, assign(socket, :admin_open, !socket.assigns.admin_open)}
  end

  def handle_event("toggle_eams", _params, socket) do
    {:noreply, assign(socket, :eams_open, !socket.assigns.eams_open)}
  end

  def handle_event("toggle_role_switcher", _params, socket) do
    {:noreply, assign(socket, :show_role_switcher, !socket.assigns.show_role_switcher)}
  end

  def handle_event("switch_role", %{"role" => role}, socket) do
    send(self(), {:switch_role, role})
    {:noreply, assign(socket, :show_role_switcher, false)}
  end

  defp get_available_roles(user) do
    # Get roles from the roles array, or fall back to single role field
    roles = if Enum.any?(user.roles || []), do: user.roles, else: [user.role]
    Enum.filter(roles, & &1)
  end

  defp get_active_role(user) do
    # Use active_role if set, otherwise use the first available role
    user.active_role || List.first(get_available_roles(user)) || user.role
  end

  defp role_display_name(role) do
    case role do
      "admin" -> "Administrator"
      "supervisor" -> "Supervisor"
      "attachee" -> "Attachee"
      "manager" -> "Manager"
      "employee" -> "Employee"
      _ -> String.capitalize(role)
    end
  end

  def render(assigns) do
    assigns = assign(assigns, :active_role, get_active_role(assigns.current_scope.user))
    assigns = assign(assigns, :available_roles, get_available_roles(assigns.current_scope.user))

    ~H"""
    <div>
      <!-- Sidebar -->
      <aside
        class={"#{if @sidebar_open, do: "translate-x-0", else: "-translate-x-full"} w-64 bg-gradient-to-b from-purple-100 via-white to-purple-50 text-gray-800 h-screen fixed top-0 left-0 p-6 shadow-xl border-r border-purple-200 z-40 transition-transform duration-300"}
      >
        <!-- Logo -->
        <div class="mb-6 text-center">
          <h1 class="text-3xl font-extrabold text-purple-700 tracking-tight">
            trial<span class="text-gray-900">app</span>
          </h1>
          <div class="h-1 w-12 mx-auto bg-purple-300 rounded-full mt-2"></div>
        </div>

        <!-- Role Switcher (only show if user has multiple roles) -->
        <%= if length(@available_roles) > 1 do %>
          <div class="mb-6 relative">
            <button
              phx-click="toggle_role_switcher"
              phx-target={@myself}
              type="button"
              class="w-full py-2.5 px-4 bg-gradient-to-r from-purple-500 to-purple-600 text-white rounded-xl hover:from-purple-600 hover:to-purple-700 transition-all duration-200 font-medium shadow-md flex justify-between items-center"
            >
              <span class="flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                  />
                </svg>
                <span class="text-sm">{role_display_name(@active_role)}</span>
              </span>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>

            <%= if @show_role_switcher do %>
              <div class="absolute top-full left-0 right-0 mt-2 bg-white rounded-xl shadow-xl border border-purple-200 py-2 z-50">
                <%= for role <- @available_roles do %>
                  <button
                    phx-click="switch_role"
                    phx-value-role={role}
                    phx-target={@myself}
                    type="button"
                    class={"w-full text-left py-2 px-4 hover:bg-purple-50 transition-colors #{if role == @active_role, do: "bg-purple-100 text-purple-700 font-semibold", else: "text-gray-700"}"}
                  >
                    <div class="flex items-center gap-2">
                      <%= if role == @active_role do %>
                        <svg class="w-4 h-4 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                          <path
                            fill-rule="evenodd"
                            d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      <% else %>
                        <div class="w-4 h-4"></div>
                      <% end %>
                      {role_display_name(role)}
                    </div>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Navigation -->
        <nav class="overflow-y-auto" style="max-height: calc(100vh - 240px);">
          <ul class="space-y-3">
            <%= case @active_role do %>
              <%# ATTACHEE VIEW %>
              <% "attachee" -> %>
                <li>
                  <.link
                    navigate={~p"/attachee"}
                    class="block py-2.5 px-4 rounded-xl bg-white/50 hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium shadow-sm"
                  >
                    Dashboard
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/attachee/tasks"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    My Tasks
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/attachee/profile"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    My Profile
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/users/settings"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Settings
                  </.link>
                </li>

                <li>
                  <.link
                    href={~p"/users/logout"}
                    method="delete"
                    class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600"
                  >
                    Logout
                  </.link>
                </li>

              <%# SUPERVISOR VIEW %>
              <% "supervisor" -> %>
                <li>
                  <.link
                    navigate={~p"/supervisor/dashboard"}
                    class="block py-2.5 px-4 rounded-xl bg-white/50 hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium shadow-sm"
                  >
                    Dashboard
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/supervisor/team"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    My Team
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/supervisor/attachees"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Attachees
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/supervisor/tasks"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Tasks
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/users/settings"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Settings
                  </.link>
                </li>

                <li>
                  <.link
                    href={~p"/users/logout"}
                    method="delete"
                    class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600"
                  >
                    Logout
                  </.link>
                </li>

              <%# ADMIN VIEW %>
              <% "admin" -> %>
                <li>
                  <.link
                    navigate={~p"/admin/dashboard"}
                    class="block py-2.5 px-4 rounded-xl bg-white/50 hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium shadow-sm"
                  >
                    Admin Dashboard
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/organizations"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Organizations
                  </.link>
                </li>

                <!-- Admin Dropdown -->
                <li>
                  <button
                    phx-click="toggle_admin"
                    phx-target={@myself}
                    type="button"
                    class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-purple-400 shadow-sm"
                  >
                    <span class="flex items-center gap-2">
                      <svg
                        class="w-4 h-4 text-purple-500"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                        />
                      </svg>
                      Admin
                    </span>
                    <span>{if @admin_open, do: "▾", else: "▸"}</span>
                  </button>

                  <%= if @admin_open do %>
                    <ul class="ml-4 mt-2 space-y-2">
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
                  <% end %>
                </li>

                <!-- EAMS Dropdown -->
                <li>
                  <button
                    phx-click="toggle_eams"
                    phx-target={@myself}
                    type="button"
                    class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-blue-400 shadow-sm"
                  >
                    <span class="flex items-center gap-2">
                      <svg
                        class="w-4 h-4 text-blue-500"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
                        />
                      </svg>
                      EAMS
                    </span>
                    <span>{if @eams_open, do: "▾", else: "▸"}</span>
                  </button>

                  <%= if @eams_open do %>
                    <ul class="ml-4 mt-2 space-y-2">
                      <li>
                        <.link
                          navigate={~p"/admin/eams/programs"}
                          class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                        >
                          Programs
                        </.link>
                      </li>
                      <li>
                        <.link
                          navigate={~p"/admin/eams/projects"}
                          class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                        >
                          Projects
                        </.link>
                      </li>
                      <li>
                        <.link
                          navigate={~p"/admin/eams/attachees"}
                          class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                        >
                          Attachees
                        </.link>
                      </li>
                      <li>
                        <.link
                          navigate={~p"/admin/eams/tasks"}
                          class="block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"
                        >
                          Tasks
                        </.link>
                      </li>
                    </ul>
                  <% end %>
                </li>

                <li>
                  <.link
                    navigate={~p"/users/settings"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Settings
                  </.link>
                </li>

                <li>
                  <.link
                    href={~p"/users/logout"}
                    method="delete"
                    class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600"
                  >
                    Logout
                  </.link>
                </li>

              <%# REGULAR USER VIEW %>
              <% _ -> %>
                <li>
                  <.link
                    navigate={~p"/dashboard"}
                    class="block py-2.5 px-4 rounded-xl bg-white/50 hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium shadow-sm"
                  >
                    Dashboard
                  </.link>
                </li>

                <li>
                  <.link
                    navigate={~p"/organizations"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Organizations
                  </.link>
                </li>

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

                <li>
                  <.link
                    navigate={~p"/users/settings"}
                    class="block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium"
                  >
                    Settings
                  </.link>
                </li>

                <li>
                  <.link
                    href={~p"/users/logout"}
                    method="delete"
                    class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600"
                  >
                    Logout
                  </.link>
                </li>
            <% end %>
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
                {role_display_name(@active_role)}
              </p>
            </div>
          </div>
        </div>
      </aside>

      <!-- Toggle Button -->
      <button
        phx-click="toggle_sidebar"
        phx-target={@myself}
        type="button"
        class={"#{if @sidebar_open, do: "left-64", else: "left-0"} fixed top-1/2 -translate-y-1/2 z-50 bg-purple-600 text-white p-1.5 rounded-r-md shadow-md transition-all duration-300 hover:bg-purple-700"}
      >
        <%= if @sidebar_open do %>
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M15 19l-7-7 7-7" />
          </svg>
        <% else %>
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M9 5l7 7-7 7" />
          </svg>
        <% end %>
      </button>
    </div>
    """
  end
end
