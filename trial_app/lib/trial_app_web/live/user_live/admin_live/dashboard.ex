defmodule TrialAppWeb.AdminLive.Dashboard do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_dashboard_data(socket)}
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
    |> assign(:recent_activity, [])
    |> assign(:page_title, "Admin Dashboard")
  end
end
