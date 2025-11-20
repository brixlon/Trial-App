defmodule TrialAppWeb.Live.Helpers.RoleSwitcher do
  use Phoenix.Component
  import Phoenix.LiveView, only: [put_flash: 3, push_navigate: 2]
  alias Phoenix.LiveView.JS
  use TrialAppWeb, :verified_routes

  alias TrialApp.Accounts

  # ───────────────────────────────────────────────────────────────
  # COMPONENT: Role Switcher Buttons
  # ───────────────────────────────────────────────────────────────
  attr :current_scope, :map, required: true
  attr :class, :string, default: ""

  def role_switcher(assigns) do
    available_roles = Accounts.get_user_roles(assigns.current_scope.user)

    ~H"""
    <div class={["flex gap-2 flex-wrap", @class]}>
      <%= for role <- available_roles do %>
        <% active = @current_scope.active_role == role %>

        <button
          phx-click={JS.push("switch_role", value: %{role: role})}
          class={
            "px-3 py-1 text-xs rounded-full font-medium transition-all " <>
              if(active,
                do: "bg-primary text-white",
                else: "bg-base-300 hover:bg-base-200"
              )
          }
          disabled={active}
        >
          <%= role_display_name(role) %>

          <%= if active do %>
            <span class="ml-1">✓</span>
          <% end %>
        </button>
      <% end %>
    </div>
    """
  end

  # ───────────────────────────────────────────────────────────────
  # ROLE SWITCH HANDLER
  # ───────────────────────────────────────────────────────────────
  def handle_role_switch(socket, new_role) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    roles = Accounts.get_user_roles(user)

    # 1. Ensure the user actually has this role
    if new_role not in roles do
      {:noreply, put_flash(socket, :error, "You don't have that role")}
    else
      # 2. Check if role requirements are satisfied
      case validate_role_requirements(user, new_role) do
        :ok ->
          # 3. Perform the switch
          {:ok, updated_user} = Accounts.switch_user_role(user, new_role)

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

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  # ───────────────────────────────────────────────────────────────
  # ROUTES FOR EACH ROLE
  # ───────────────────────────────────────────────────────────────
  defp dashboard_path_for_role("admin"), do: ~p"/admin/dashboard"
  defp dashboard_path_for_role("supervisor"), do: ~p"/supervisor/dashboard"
  defp dashboard_path_for_role("attachee"), do: ~p"/attachee"
  defp dashboard_path_for_role(_), do: ~p"/dashboard"

  # ───────────────────────────────────────────────────────────────
  # NAME DISPLAY
  # ───────────────────────────────────────────────────────────────
  defp role_display_name("admin"), do: "Admin"
  defp role_display_name("supervisor"), do: "Supervisor"
  defp role_display_name("attachee"), do: "Attachee"
  defp role_display_name(role), do: String.capitalize(role)

  # ───────────────────────────────────────────────────────────────
  # ROLE REQUIREMENT VALIDATION
  # ───────────────────────────────────────────────────────────────
  defp validate_role_requirements(_user, "admin"), do: :ok

  defp validate_role_requirements(user, "supervisor") do
    if user.assigned_department_id do
      :ok
    else
      {:error, "You are not assigned to any department as a supervisor"}
    end
  end

  defp validate_role_requirements(user, "attachee") do
    has_profile =
      Map.has_key?(user, :attachee_profile) and not is_nil(user.attachee_profile)

    if has_profile do
      :ok
    else
      {:error, "You do not have an attachee profile"}
    end
  end

  defp validate_role_requirements(_, _), do: {:error, "Invalid role"}
end
