defmodule TrialAppWeb.SidebarComponent do
  use TrialAppWeb, :live_component

  alias TrialApp.Accounts

  def mount(socket) do
    {:ok,
     socket
     |> assign(:sidebar_open, true)
     |> assign(:admin_open, false)
     |> assign(:eams_open, false)
     |> assign(:supervision_open, false)
     |> assign(:show_role_switcher, false)
     |> assign(:active_role, nil)
     |> assign(:available_roles, [])
     |> assign(:current_path, nil)}
  end

  def update(assigns, socket) do
    user = assigns.current_scope.user
    active_role = Accounts.get_active_role(user)
    available_roles = Accounts.get_user_roles(user)

    # Get current path from URI if available
    current_path = case assigns[:uri] do
      nil -> nil
      uri -> uri.path
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:active_role, active_role)
     |> assign(:available_roles, available_roles)
     |> assign(:current_path, current_path)}
  end

  def handle_event("toggle_sidebar", _params, socket), do: {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  def handle_event("toggle_admin", _params, socket), do: {:noreply, assign(socket, :admin_open, !socket.assigns.admin_open)}
  def handle_event("toggle_eams", _params, socket), do: {:noreply, assign(socket, :eams_open, !socket.assigns.eams_open)}
  def handle_event("toggle_supervision", _params, socket), do: {:noreply, assign(socket, :supervision_open, !socket.assigns.supervision_open)}
  def handle_event("toggle_role_switcher", _params, socket), do: {:noreply, assign(socket, :show_role_switcher, !socket.assigns.show_role_switcher)}

  def handle_event("switch_role", %{"role" => role}, socket) do
    send(self(), {:switch_role, role})
    {:noreply, assign(socket, :show_role_switcher, false)}
  end

  defp role_display_name(role) do
    case role do
      "admin" -> "Administrator"
      "supervisor" -> "Supervisor"
      "attachee" -> "Attachee"
      "manager" -> "Manager"
      "employee" -> "Employee"
      _ -> String.capitalize(role || "User")
    end
  end

  defp active_link?(current_path, link_path) do
    current_path && String.starts_with?(current_path, link_path)
  end

  defp link_class(current_path, link_path, base_classes \\ "") do
    if active_link?(current_path, link_path) do
      "block py-2.5 px-4 rounded-xl bg-purple-200 text-purple-900 font-semibold shadow-md #{base_classes}"
    else
      "block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium #{base_classes}"
    end
  end

  def render(assigns) do
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

        <!-- Role Switcher -->
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
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span class="text-sm">{role_display_name(@active_role)}</span>
              </span>
              <svg class={"w-4 h-4 transition-transform #{if @show_role_switcher, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
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
              <% "attachee" -> %>
                <li><.link navigate={~p"/attachee"} class={link_class(@current_path, "/attachee")}>Dashboard</.link></li>
                <li><.link navigate={~p"/attachee/tasks"} class={link_class(@current_path, "/attachee/tasks")}>My Tasks</.link></li>
                <li><.link navigate={~p"/attachee/profile"} class={link_class(@current_path, "/attachee/profile")}>My Profile</.link></li>
                <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings")}>Settings</.link></li>
                <li><.link href={~p"/users/logout"} method="delete" class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600">Logout</.link></li>

              <% "supervisor" -> %>
                <li><.link navigate={~p"/supervisor/dashboard"} class={link_class(@current_path, "/supervisor/dashboard")}>Dashboard</.link></li>
                <li><.link navigate={~p"/supervisor/attachees"} class={link_class(@current_path, "/supervisor/attachees")}>Manage Attachees</.link></li>
                <li><.link navigate={~p"/supervisor/tasks"} class={link_class(@current_path, "/supervisor/tasks")}>Tasks</.link></li>
                <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings")}>Settings</.link></li>
                <li><.link href={~p"/users/logout"} method="delete" class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600">Logout</.link></li>

              <% "admin" -> %>
                <li><.link navigate={~p"/admin/dashboard"} class={link_class(@current_path, "/admin/dashboard")}>Admin Dashboard</.link></li>
                <li><.link navigate={~p"/organizations"} class={link_class(@current_path, "/organizations")}>Organizations</.link></li>

                <!-- Admin Dropdown -->
                <li>
                  <button phx-click="toggle_admin" phx-target={@myself} type="button" class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-purple-400 shadow-sm">
                    <span class="flex items-center gap-2">
                      <svg class="w-4 h-4 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                      Admin
                    </span>
                    <svg class={"w-4 h-4 transition-transform #{if @admin_open, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <%= if @admin_open do %>
                    <ul class="ml-4 mt-2 space-y-2">
                      <li><.link navigate={~p"/admin/users"} class={if active_link?(@current_path, "/admin/users"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>User Management</.link></li>
                      <li><.link navigate={~p"/admin/employees"} class={if active_link?(@current_path, "/admin/employees"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Employees</.link></li>
                      <li><.link navigate={~p"/admin/positions"} class={if active_link?(@current_path, "/admin/positions"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Positions</.link></li>
                    </ul>
                  <% end %>
                </li>

                <!-- EAMS Dropdown -->
                <li>
                  <button phx-click="toggle_eams" phx-target={@myself} type="button" class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-blue-400 shadow-sm">
                    <span class="flex items-center gap-2">
                      <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/></svg>
                      EAMS
                    </span>
                    <svg class={"w-4 h-4 transition-transform #{if @eams_open, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <%= if @eams_open do %>
                    <ul class="ml-4 mt-2 space-y-2">
                      <li><.link navigate={~p"/admin/eams/programs"} class={if active_link?(@current_path, "/admin/eams/programs"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Programs</.link></li>
                      <li><.link navigate={~p"/admin/eams/projects"} class={if active_link?(@current_path, "/admin/eams/projects"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Projects</.link></li>
                      <li><.link navigate={~p"/admin/eams/attachees"} class={if active_link?(@current_path, "/admin/eams/attachees"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Attachees</.link></li>
                      <li><.link navigate={~p"/admin/eams/tasks"} class={if active_link?(@current_path, "/admin/eams/tasks"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Tasks</.link></li>
                    </ul>
                  <% end %>
                </li>

                <!-- Evaluation Dropdown -->
                <li>
                  <button phx-click="toggle_supervision" phx-target={@myself} type="button" class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-indigo-400 shadow-sm">
                    <span class="flex items-center gap-2">
                      <svg class="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/></svg>
                      Evaluation
                    </span>
                    <svg class={"w-4 h-4 transition-transform #{if @supervision_open, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <%= if @supervision_open do %>
                    <ul class="ml-4 mt-2 space-y-2">
                      <li><.link navigate={~p"/supervisor/attachees"} class={if active_link?(@current_path, "/supervisor/attachees"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Attachee Evaluation</.link></li>
                      <li><.link navigate={~p"/supervisor/tasks"} class={if active_link?(@current_path, "/supervisor/tasks"), do: "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-semibold text-sm", else: "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm"}>Task Management</.link></li>
                    </ul>
                  <% end %>
                </li>

                <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings")}>Settings</.link></li>
                <li><.link href={~p"/users/logout"} method="delete" class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600">Logout</.link></li>

              <% _ -> %>
                <li><.link navigate={~p"/dashboard"} class={link_class(@current_path, "/dashboard")}>Dashboard</.link></li>
                <li><.link navigate={~p"/organizations"} class={link_class(@current_path, "/organizations")}>Organizations</.link></li>
                <li><.link navigate={~p"/employees"} class={link_class(@current_path, "/employees")}>Employees</.link></li>
                <li><.link navigate={~p"/positions"} class={link_class(@current_path, "/positions")}>Positions</.link></li>
                <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings")}>Settings</.link></li>
                <li><.link href={~p"/users/logout"} method="delete" class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600">Logout</.link></li>
            <% end %>
          </ul>
        </nav>

        <!-- User Info -->
        <div class="absolute bottom-6 left-6 right-6 p-4 bg-white/80 rounded-xl border border-purple-200 shadow-md backdrop-blur-sm">
          <div class="flex items-center space-x-3">
            <div class="w-9 h-9 bg-purple-100 rounded-full flex items-center justify-center">
              <span class="text-purple-700 font-bold text-sm">
                {String.at(@current_scope.user.username || @current_scope.user.email, 0) |> String.upcase()}
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-gray-800 truncate">
                {@current_scope.user.username || @current_scope.user.email}
              </p>
              <p class="text-xs text-purple-600 truncate">
                {role_display_name(@active_role)}
              </p>
            </div>
          </div>
        </div>
      </aside>

      <!-- Toggle Button -->
      <button phx-click="toggle_sidebar" phx-target={@myself} type="button" class={"#{if @sidebar_open, do: "left-64", else: "left-0"} fixed top-1/2 -translate-y-1/2 z-50 bg-purple-600 text-white p-1.5 rounded-r-md shadow-md transition-all duration-300 hover:bg-purple-700"}>
        <%= if @sidebar_open do %>
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M15 19l-7-7 7-7" /></svg>
        <% else %>
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M9 5l7 7-7 7" /></svg>
        <% end %>
      </button>
    </div>
    """
  end
end
