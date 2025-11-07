defmodule TrialAppWeb.Live.Helpers.RoleSwitcher do
  import Phoenix.Component
  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3]
  use TrialAppWeb, :verified_routes

  alias TrialApp.Accounts

  @doc """
  Handles role switching for a LiveView socket.
  Updates the user's active role and redirects to the appropriate dashboard.
  """
  def handle_role_switch(socket, new_role) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user

    # Verify user has this role
    if new_role in user.roles do
      # Update the user's active role in the database
      case Accounts.switch_user_role(user, new_role) do
        {:ok, updated_user} ->
          # Create updated scope with new role
          updated_scope = %{current_scope |
            user: updated_user,
            active_role: new_role,
            roles: updated_user.roles,
            is_admin: "admin" in updated_user.roles,
            is_supervisor: "supervisor" in updated_user.roles,
            is_attachee: "attachee" in updated_user.roles
          }

          # Update socket assigns and redirect
          {:noreply,
           socket
           |> assign(:current_scope, updated_scope)
           |> assign(:current_user, updated_user)
           |> put_flash(:info, "Switched to #{role_display_name(new_role)} view")
           |> push_navigate(to: dashboard_path_for_role(new_role))}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to switch role. Please try again.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to switch to that role.")}
    end
  end

  # Get the dashboard path for a role
  defp dashboard_path_for_role(role) do
    case role do
      "admin" -> ~p"/admin/dashboard"
      "supervisor" -> ~p"/supervisor/dashboard"
      "attachee" -> ~p"/attachee"
      _ -> ~p"/dashboard"
    end
  end

  # Get display name for role
  defp role_display_name(role) do
    case role do
      "admin" -> "Administrator"
      "supervisor" -> "Supervisor"
      "attachee" -> "Attachee"
      _ -> String.capitalize(role)
    end
  end
end
