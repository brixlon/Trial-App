defmodule TrialAppWeb.RoleSwitcherComponent do
  use TrialAppWeb, :live_component

  alias TrialApp.Accounts

  def render(assigns) do
    ~H"""
    <div class="relative" x-data="{ open: false }">
      <!-- Current Role Button -->
      <button @click="open = !open" class="flex items-center space-x-2 px-3 py-1.5 rounded-lg bg-gray-100 hover:bg-gray-200 text-sm font-medium text-gray-700">
        <span><%= TrialApp.Accounts.Scope.role_display_name(@current_scope.active_role) %></span>
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <!-- Dropdown -->
      <div x-show="open" @click.away="open = false" class="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
        <div class="py-1">
          <%= for role <- @current_scope.roles do %>
            <.link
              href="#"
              phx-click="switch_role"
              phx-value-role={role}
              phx-target={@myself}
              class={"block px-4 py-2 text-sm hover:bg-gray-100 #{if role == @current_scope.active_role, do: "bg-indigo-50 text-indigo-700", else: "text-gray-700"}"}
            >
              <%= TrialApp.Accounts.Scope.role_display_name(role) %>
              <%= if role == @current_scope.active_role do %>
                <span class="ml-2 text-xs">(current)</span>
              <% end %>
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("switch_role", %{"role" => new_role}, socket) do
    scope = socket.assigns.current_scope
    user = scope.user

    if new_role in user.roles do
      case Accounts.update_user_active_role(user, new_role) do
        {:ok, updated_user} ->
          new_scope = Accounts.Scope.for_user(updated_user, active_role: new_role)
          socket = assign(socket, :current_scope, new_scope)
          socket = push_navigate(socket, to: Accounts.Scope.role_dashboard_path(new_role))
          {:noreply, socket}

        {:error, _} ->
          socket = put_flash(socket, :error, "Failed to switch role")
          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid role")}
    end
  end
end
