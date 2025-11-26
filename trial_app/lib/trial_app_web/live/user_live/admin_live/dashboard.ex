defmodule TrialAppWeb.AdminLive.Dashboard do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to activity updates for real-time notifications
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TrialApp.PubSub, "activity_logs")
      # Schedule periodic refresh every 30 seconds as fallback
      schedule_activity_refresh()
    end

    {:ok, assign_dashboard_data(socket)}
  end

  @impl true
  def handle_info(:refresh_activity, socket) do
    # Refresh activity data
    recent_activity = TrialApp.ActivityLogs.list_recent_activity(10)

    # Schedule next refresh
    schedule_activity_refresh()

    {:noreply, assign(socket, :recent_activity, recent_activity)}
  end

  def handle_info({:activity_created, _activity}, socket) do
    # Reload activity when new activity is broadcast
    recent_activity = TrialApp.ActivityLogs.list_recent_activity(10)
    {:noreply, assign(socket, :recent_activity, recent_activity)}
  end

  def handle_info({:switch_role, new_role}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.switch_user_role(user, new_role) do
      {:ok, updated_user} ->
        # Update the socket with the new user data
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        # Redirect to the appropriate dashboard for the new role
        redirect_path =
          case new_role do
            "admin" -> ~p"/admin/dashboard"
            "supervisor" -> ~p"/supervisor/dashboard"
            "attachee" -> ~p"/attachee"
            "manager" -> ~p"/dashboard"
            "employee" -> ~p"/dashboard"
            _ -> ~p"/dashboard"
          end

        {:noreply,
         socket
         |> assign(:current_scope, updated_scope)
         # |> put_flash(:info, "Switched to #{new_role} role")
         |> push_navigate(to: redirect_path)}

      {:error, :unauthorized_role} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to switch to that role")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to switch role")}
    end
  end

  # Schedule activity refresh every 30 seconds
  defp schedule_activity_refresh do
    Process.send_after(self(), :refresh_activity, 30_000)
  end

  # Helper function to assign stats
  defp assign_dashboard_data(socket) do
    total_users = Accounts.list_users() |> length()
    pending_users = Accounts.list_users_by_status("pending") |> length()
    active_users = Accounts.list_users_by_status("active") |> length()
    admin_users = Accounts.list_users_by_role("admin") |> length()

    socket
    |> assign(:total_users, total_users)
    |> assign(:pending_users, pending_users)
    |> assign(:active_users, active_users)
    |> assign(:admin_users, admin_users)
    |> assign(:pending_projects_count, length(TrialApp.Eams.list_pending_projects()))
    |> assign(:recent_activity, TrialApp.ActivityLogs.list_recent_activity(10))
    |> assign(:recent_users, Accounts.list_recent_users(5))
    |> assign(:attachees_by_dept, TrialApp.Eams.count_attachees_by_department())
    |> assign(:projects_by_status, TrialApp.Eams.count_projects_by_status())
    |> assign(:page_title, "Admin Dashboard")
  end
end
