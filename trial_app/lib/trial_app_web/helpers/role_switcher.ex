defmodule TrialAppWeb.Live.Helpers.RoleSwitcher do
  use Phoenix.Component

  # Import LiveView helpers
  import Phoenix.LiveView, only: [put_flash: 3, push_navigate: 2]

  # Import verified routes macro
  use TrialAppWeb, :verified_routes

  alias TrialApp.Accounts

  # ──────────────────────────────────────────────────────────────────────
  # COMPONENT: Role Switcher Buttons
  # ──────────────────────────────────────────────────────────────────────
  attr :current_scope, :map, required: true
  attr :class, :string, default: ""

  def role_switcher(assigns) do
    ~H"""
    <div class={["flex gap-2 flex-wrap", @class]}>
      <%= for role <- @current_user.roles do %>
        <% active = @current_scope.active_role == role %>
        <button
          phx-click={JS.push("switch_role", value: %{role: role})}
          class={"px-3 py-1 text-xs rounded-full font-medium transition-all #{if active, do: "bg-primary text-white", else: "bg-base-300 hover:bg-base-200"}"}
          disabled={active}
        >
          <%= role_display_name(role) %>
          <%= if active do %>
            <span class="ml-1">Checkmark</span>
          <% end %>
        </button>
      <% end %>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────
  # HANDLER: Switch Role
  # ──────────────────────────────────────────────────────────────────────
  def handle_role_switch(socket, new_role) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user

    if new_role in user.roles do
      case Accounts.switch_user_role(user, new_role) do
        {:ok, updated_user} ->
          updated_scope = %{
            current_scope
            | user: updated_user,
              active_role: new_role,
              is_admin: new_role == "admin",
              is_supervisor: new_role == "supervisor",
              is_attachee: new_role == "attachee"
          }

          {:noreply,
           socket
           |> assign(:current_scope, updated_scope)
           |> assign(:current_user, updated_user)
           |> put_flash(:info, "Switched to #{role_display_name(new_role)}")
           |> push_navigate(to: dashboard_path_for_role(new_role))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to switch role")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized role")}
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # PRIVATE HELPERS
  # ──────────────────────────────────────────────────────────────────────
  defp dashboard_path_for_role("admin"), do: ~p"/admin/dashboard"
  defp dashboard_path_for_role("supervisor"), do: ~p"/supervisor/dashboard"
  defp dashboard_path_for_role("attachee"), do: ~p"/attachee"
  defp dashboard_path_for_role(_), do: ~p"/dashboard"

  defp role_display_name("admin"), do: "Admin"
  defp role_display_name("supervisor"), do: "Supervisor"
  defp role_display_name("attachee"), do: "Attachee"
  defp role_display_name(role), do: String.capitalize(role)
end
