defmodule TrialAppWeb.TeamLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)}
    else
      # User is active, show team data
      # Mock data - in real app, this would come from database
      # For now, we'll simulate: total teams = 3, user's team = Frontend Team
      all_teams = [
        %{id: 1, name: "Frontend Team", description: "UI/UX development"},
        %{id: 2, name: "Backend Team", description: "Server-side logic"},
        %{id: 3, name: "DevOps Team", description: "Infrastructure and deployment"}
      ]

      # User's assigned team (in real app, this would come from user context)
      user_team = %{id: 1, name: "Frontend Team", description: "UI/UX development"}

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, true)
       |> assign(:total_teams, length(all_teams))
       |> assign(:user_team, user_team)
       |> stream(:teams, [user_team])}
    end
  end
end
