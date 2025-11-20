defmodule TrialAppWeb.SidebarComponent do
  use TrialAppWeb, :live_component

  alias TrialApp.Accounts

  @reserved_assigns [:socket, :flash, :myself, :inner_block, :__changed__]

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
     |> assign(:current_path, nil)
     |> assign(:unread_count, 0)
     |> assign(:show_notifications, false)}
  end

  def update(assigns, socket) do
    # CRITICAL: Remove reserved assigns to avoid :socket error
    safe_assigns = Map.drop(assigns, @reserved_assigns)

    user = safe_assigns.current_scope.user
    active_role = Accounts.get_active_role(user)
    available_roles = Accounts.get_user_roles(user)

    unread_count =
      if active_role in ["admin", "supervisor", "attachee"] do
        TrialApp.Announcements.get_unread_count(user.id, active_role)
      else
        0
      end

    current_path = assigns[:uri] && assigns[:uri].path

    {:ok,
     socket
     |> assign(safe_assigns)
     |> assign(:active_role, active_role)
     |> assign(:available_roles, available_roles)
     |> assign(:current_path, current_path)
     |> assign(:unread_count, unread_count)
     |> assign(:show_notifications, false)}
  end

  # === EVENT HANDLERS ===
  def handle_event("toggle_sidebar", _params, socket),
    do: {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}

  def handle_event("toggle_admin", _params, socket),
    do: {:noreply, assign(socket, :admin_open, !socket.assigns.admin_open)}

  def handle_event("toggle_eams", _params, socket),
    do: {:noreply, assign(socket, :eams_open, !socket.assigns.eams_open)}

  def handle_event("toggle_supervision", _params, socket),
    do: {:noreply, assign(socket, :supervision_open, !socket.assigns.supervision_open)}

  def handle_event("toggle_role_switcher", _params, socket),
    do: {:noreply, assign(socket, :show_role_switcher, !socket.assigns.show_role_switcher)}

  def handle_event("switch_role", %{"role" => role}, socket) do
    send(self(), {:switch_role, role})
    {:noreply, assign(socket, :show_role_switcher, false)}
  end

  def handle_event("toggle_notifications", _params, socket),
    do: {:noreply, assign(socket, :show_notifications, !socket.assigns.show_notifications)}

  # === HELPERS ===
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

  defp active_link?(current_path, link_path, exact: exact) do
    if exact do
      current_path == link_path
    else
      current_path && String.starts_with?(current_path, link_path)
    end
  end

  defp link_class(current_path, link_path, opts \\ []) do
    exact = Keyword.get(opts, :exact, false)

    if active_link?(current_path, link_path, exact: exact) do
      "block py-2.5 px-4 rounded-xl bg-purple-600 text-white font-bold shadow-md"
    else
      "block py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-medium text-gray-700"
    end
  end

  defp dropdown_link_class(current_path, link_path) do
    if current_path == link_path do
      "block py-1.5 px-3 rounded-lg bg-purple-100 text-purple-700 font-bold text-sm"
    else
      "block py-1.5 px-3 rounded-lg hover:bg-purple-100 hover:text-purple-700 transition-colors text-sm text-gray-700"
    end
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  # === RENDER ===
  def render(assigns) do
    ~H"""
    <div>
      <aside
        class={
          "#{if @sidebar_open, do: "translate-x-0", else: "-translate-x-full"}
          w-64 bg-gradient-to-b from-purple-100 via-white to-purple-50 text-gray-800
          h-screen fixed top-0 left-0 shadow-xl border-r border-purple-200 z-40
          transition-transform duration-300 flex flex-col"
        }
      >
        <div class="p-6 space-y-6 flex-shrink-0">
          <div class="text-center">
            <h1 class="text-3xl font-extrabold text-purple-700 tracking-tight">
              trial<span class="text-gray-900">app</span>
            </h1>
            <div class="h-1 w-12 mx-auto bg-purple-300 rounded-full mt-2"></div>
          </div>

          <%= if length(@available_roles) > 1 do %>
            <div class="relative">
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

          <%= if @active_role in ["admin", "supervisor", "attachee"] do %>
            <div class="relative">
              <button
                phx-click="toggle_notifications"
                phx-target={@myself}
                type="button"
                class="w-full py-2.5 px-4 bg-white rounded-xl hover:bg-purple-50 transition-all duration-200 font-medium shadow-sm border border-gray-200 flex justify-between items-center group"
              >
                <span class="flex items-center gap-2.5 text-gray-700 group-hover:text-purple-700 transition-colors">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                  </svg>
                  <span class="text-sm font-medium">Announcements</span>
                </span>
                <%= if @unread_count > 0 do %>
                  <span class="inline-flex items-center justify-center min-w-[24px] h-6 px-2 text-xs font-bold text-white bg-red-600 rounded-full animate-pulse">
                    <%= if @unread_count > 9, do: "9+", else: @unread_count %>
                  </span>
                <% end %>
              </button>

              <%= if @show_notifications do %>
                <div class="absolute top-full left-0 right-0 mt-2 bg-white rounded-xl shadow-2xl border border-gray-200 z-50 overflow-hidden">
                  <div class="px-4 py-3 bg-gradient-to-r from-purple-50 to-purple-100 border-b border-purple-200">
                    <h3 class="text-sm font-bold text-gray-900 flex items-center justify-between">
                      <span>Recent Announcements</span>
                      <%= if @unread_count > 0 do %>
                        <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-700">
                          <%= @unread_count %> new
                        </span>
                      <% end %>
                    </h3>
                  </div>

                  <div class="max-h-[400px] overflow-y-auto">
                    <%= case TrialApp.Announcements.list_announcements_for_user(@current_scope.user.id, @active_role) |> Enum.take(10) do %>
                      <% [] -> %>
                        <div class="px-4 py-12 text-center">
                          <svg class="w-12 h-12 mx-auto text-gray-300 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>
                          </svg>
                          <p class="text-sm font-medium text-gray-900 mb-1">No announcements yet</p>
                          <p class="text-xs text-gray-500">Check back later for updates</p>
                        </div>
                      <% announcements -> %>
                        <%= for announcement <- announcements do %>
                          <.link navigate={~p"/announcements"} class="block px-4 py-3 hover:bg-purple-50 border-b border-gray-100 last:border-b-0 transition-colors group">
                            <div class="flex items-start gap-3">
                              <%= if not TrialApp.Announcements.is_read?(announcement.id, @current_scope.user.id) do %>
                                <div class="w-2 h-2 bg-blue-600 rounded-full mt-2 flex-shrink-0"></div>
                              <% else %>
                                <div class="w-2 h-2 mt-2 flex-shrink-0"></div>
                              <% end %>
                              <div class="flex-1 min-w-0">
                                <div class="flex items-center gap-1.5 mb-1.5">
                                  <%= if announcement.pinned do %>
                                    <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-700">Pinned</span>
                                  <% end %>
                                  <span class={"inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium #{case announcement.priority do
                                    "urgent" -> "bg-red-100 text-red-700"
                                    "important" -> "bg-yellow-100 text-yellow-700"
                                    _ -> "bg-gray-100 text-gray-600"
                                  end}"}>
                                    <%= String.upcase(announcement.priority) %>
                                  </span>
                                </div>
                                <p class="text-sm font-semibold text-gray-900 group-hover:text-purple-700 transition-colors line-clamp-1 mb-1">
                                  <%= announcement.title %>
                                </p>
                                <p class="text-xs text-gray-600 line-clamp-2 mb-2 leading-relaxed">
                                  <%= announcement.content %>
                                </p>
                                <div class="flex items-center gap-2 text-xs text-gray-500">
                                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                                  </svg>
                                  <span><%= format_relative_time(announcement.publish_date) %></span>
                                  <%= if length(announcement.links) > 0 do %>
                                    <span>•</span>
                                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                                    </svg>
                                    <span><%= length(announcement.links) %></span>
                                  <% end %>
                                </div>
                              </div>
                            </div>
                          </.link>
                        <% end %>
                    <% end %>
                  </div>
                  <div class="px-4 py-3 bg-gray-50 border-t border-gray-200">
                    <.link navigate={~p"/announcements"} class="block text-center text-sm font-semibold text-purple-600 hover:text-purple-800 transition-colors">
                      View All Announcements
                    </.link>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex-1 overflow-y-auto px-6 pb-6">
          <nav>
            <ul class="space-y-3">
              <%= case @active_role do %>
                <% "attachee" -> %>
                  <li><.link navigate={~p"/attachee"} class={link_class(@current_path, "/attachee", exact: true)}>Dashboard</.link></li>
                  <li><.link navigate={~p"/attachee/tasks"} class={link_class(@current_path, "/attachee/tasks", exact: true)}>My Tasks</.link></li>
                  <li><.link navigate={~p"/announcements"} class={link_class(@current_path, "/announcements", exact: true)}>Announcements</.link></li>
                  <li><.link navigate={~p"/attachee/profile"} class={link_class(@current_path, "/attachee/profile", exact: true)}>My Profile</.link></li>
                  <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings", exact: true)}>Settings</.link></li>

                <% "supervisor" -> %>
                  <li><.link navigate={~p"/supervisor/dashboard"} class={link_class(@current_path, "/supervisor/dashboard", exact: true)}>Dashboard</.link></li>
                  <li><.link navigate={~p"/supervisor/attachees"} class={link_class(@current_path, "/supervisor/attachees", exact: true)}>Manage Attachees</.link></li>
                  <li><.link navigate={~p"/supervisor/tasks"} class={link_class(@current_path, "/supervisor/tasks", exact: true)}>Task Review</.link></li>
                  <li><.link navigate={~p"/announcements"} class={link_class(@current_path, "/announcements", exact: true)}>Announcements</.link></li>
                  <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings", exact: true)}>Settings</.link></li>

                <% "admin" -> %>
                  <li><.link navigate={~p"/admin/dashboard"} class={link_class(@current_path, "/admin/dashboard", exact: true)}>Admin Dashboard</.link></li>
                  <li><.link navigate={~p"/organizations"} class={link_class(@current_path, "/organizations", exact: true)}>Organizations</.link></li>

                  <li>
                    <button phx-click="toggle_admin" phx-target={@myself} class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-purple-400 shadow-sm">
                      <span class="flex items-center gap-2">
                        <svg class="w-4 h-4 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        </svg>
                        Admin
                      </span>
                      <svg class={"w-4 h-4 transition-transform #{if @admin_open, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>
                    <%= if @admin_open do %>
                      <ul class="ml-4 mt-2 space-y-2">
                        <li><.link navigate={~p"/admin/users"} class={dropdown_link_class(@current_path, "/admin/users")}>User Management</.link></li>
                        <li><.link navigate={~p"/admin/employees"} class={dropdown_link_class(@current_path, "/admin/employees")}>Employees</.link></li>
                        <li><.link navigate={~p"/admin/positions"} class={dropdown_link_class(@current_path, "/admin/positions")}>Positions</.link></li>
                      </ul>
                    <% end %>
                  </li>

                  <li>
                    <button phx-click="toggle_eams" phx-target={@myself} class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-blue-400 shadow-sm">
                      <span class="flex items-center gap-2">
                        <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
                        </svg>
                        EAMS
                      </span>
                      <svg class={"w-4 h-4 transition-transform #{if @eams_open, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>
                    <%= if @eams_open do %>
                      <ul class="ml-4 mt-2 space-y-2">
                        <li><.link navigate={~p"/admin/eams/programs"} class={dropdown_link_class(@current_path, "/admin/eams/programs")}>Programs</.link></li>
                        <li><.link navigate={~p"/admin/eams/projects"} class={dropdown_link_class(@current_path, "/admin/eams/projects")}>Projects</.link></li>
                        <li><.link navigate={~p"/admin/eams/attachees/manage"} class={dropdown_link_class(@current_path, "/admin/eams/attachees/manage")}>Attachees</.link></li>
                        <li><.link navigate={~p"/admin/eams/tasks"} class={dropdown_link_class(@current_path, "/admin/eams/tasks")}>Tasks</.link></li>
                        <li><.link navigate={~p"/announcements"} class={dropdown_link_class(@current_path, "/announcements")}>Announcements</.link></li>
                      </ul>
                    <% end %>
                  </li>

                  <li>
                    <button phx-click="toggle_supervision" phx-target={@myself} class="w-full text-left py-2.5 px-4 rounded-xl hover:bg-purple-100 hover:text-purple-700 transition-all duration-200 font-semibold flex justify-between items-center bg-white/40 border-l-4 border-indigo-400 shadow-sm">
                      <span class="flex items-center gap-2">
                        <svg class="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
                        </svg>
                        Evaluation
                      </span>
                      <svg class={"w-4 h-4 transition-transform #{if @supervision_open, do: "rotate-180", else: ""}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>
                    <%= if @supervision_open do %>
                      <ul class="ml-4 mt-2 space-y-2">
                        <li><.link navigate={~p"/supervisor/attachees"} class={dropdown_link_class(@current_path, "/supervisor/attachees")}>Attachee Evaluation</.link></li>
                        <li><.link navigate={~p"/supervisor/tasks"} class={dropdown_link_class(@current_path, "/supervisor/tasks")}>Task Review</.link></li>
                      </ul>
                    <% end %>
                  </li>

                  <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings", exact: true)}>Settings</.link></li>

                <% _ -> %>
                  <li><.link navigate={~p"/dashboard"} class={link_class(@current_path, "/dashboard", exact: true)}>Dashboard</.link></li>
                  <li><.link navigate={~p"/organizations"} class={link_class(@current_path, "/organizations", exact: true)}>Organizations</.link></li>
                  <li><.link navigate={~p"/employees"} class={link_class(@current_path, "/employees", exact: true)}>Employees</.link></li>
                  <li><.link navigate={~p"/users/settings"} class={link_class(@current_path, "/users/settings", exact: true)}>Settings</.link></li>
              <% end %>

              <li class="mt-6 pt-6 border-t border-purple-200">
                <.link href={~p"/users/logout"} method="delete" class="block py-2.5 px-4 rounded-xl hover:bg-red-100 hover:text-red-700 transition-all duration-200 font-medium text-red-600 flex items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
                  </svg>
                  Logout
                </.link>
              </li>
            </ul>
          </nav>
        </div>

        <div class="p-6 flex-shrink-0">
          <div class="p-4 bg-white/80 rounded-xl border border-purple-200 shadow-md backdrop-blur-sm">
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
        </div>
      </aside>

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
