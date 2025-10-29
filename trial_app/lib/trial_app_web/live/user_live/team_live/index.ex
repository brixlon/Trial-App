defmodule TrialAppWeb.TeamLive.Index do
  use TrialAppWeb, :live_view
  alias TrialApp.Orgs

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)
       |> assign(:total_teams, 0)
       |> assign(:user_team, nil)}
    else
      # User is active, show team data from database
      # Get the user's employee records (they might be in multiple teams)
      employees = Orgs.list_employees_by_user(current_user.id)

      # Get the first team assignment (or nil if no assignments)
      user_team = if Enum.any?(employees) do
        first_employee = List.first(employees)
        first_employee.team
      else
        nil
      end

      # Get all teams in the user's organization(s)
      all_teams = if user_team do
        Orgs.list_teams_by_organization(user_team.organization_id)
      else
        []
      end

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, !is_nil(user_team))
       |> assign(:total_teams, length(all_teams))
       |> assign(:user_team, user_team)
       |> assign(:all_user_teams, Enum.map(employees, & &1.team))
       |> stream(:teams, if(user_team, do: [user_team], else: []))}
    end
  end
end
