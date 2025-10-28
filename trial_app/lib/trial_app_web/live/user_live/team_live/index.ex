defmodule TrialAppWeb.TeamLive.Index do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations
  alias TrialApp.Accounts.User

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    cond do
      current_user.status == "pending" ->
        {:ok,
         socket
         |> assign(:user_status, "pending")
         |> assign(:has_assignments, false)}

      current_user.role in ["admin", "manager"] ->
        teams = Organizations.list_all_teams()

        {:ok,
         socket
         |> assign(:user_status, "active")
         |> assign(:is_admin, true)
         |> assign(:teams, teams)
         |> assign(:available_users, [])
         |> assign(:selected_team_id, nil)
         |> assign(:total_teams, length(teams))
         |> stream(:teams, teams)}

      true ->
        # Regular user — only see their assigned team
        user_team = Organizations.get_user_team(current_user)

        teams = if user_team, do: [user_team], else: []
        total_teams = if user_team, do: 1, else: 0

        {:ok,
         socket
         |> assign(:user_status, "active")
         |> assign(:is_admin, false)
         |> assign(:teams, teams)
         |> assign(:total_teams, total_teams)
         |> stream(:teams, teams)}
    end
  end

  # Load available users when admin clicks "Add Member"
  def handle_event("show_add_member", %{"team_id" => team_id}, socket) do
    available_users = Organizations.list_users_not_in_team(team_id)

    {:noreply,
     socket
     |> assign(:available_users, available_users)
     |> assign(:selected_team_id, String.to_integer(team_id))}
  end

  # Add user to team
  def handle_event("add_member", %{"user_id" => user_id}, socket) do
    team_id = socket.assigns.selected_team_id

    case Organizations.add_user_to_team(String.to_integer(user_id), team_id) do
      {:ok, _employee} ->
        teams = Organizations.list_all_teams()
        {:noreply,
         socket
         |> assign(:teams, teams)
         |> assign(:available_users, [])
         |> assign(:selected_team_id, nil)
         |> stream(:teams, teams)
         |> put_flash(:info, "Member added successfully!")}

      {:error, :already_exists} ->
        {:noreply, put_flash(socket, :error, "User is already in the team.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add member.")}
    end
  end

  # Remove a user from team
  def handle_event("remove_member", %{"employee_id" => employee_id}, socket) do
    case Organizations.remove_user_from_team(String.to_integer(employee_id)) do
      {:ok, _} ->
        teams = Organizations.list_all_teams()
        {:noreply,
         socket
         |> assign(:teams, teams)
         |> stream(:teams, teams)
         |> put_flash(:info, "Member removed successfully.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member.")}
    end
  end
end
