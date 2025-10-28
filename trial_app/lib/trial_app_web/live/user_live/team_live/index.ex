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

<<<<<<< Updated upstream
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />
        <main class="ml-64 p-8 w-full">
          <div class="max-w-6xl mx-auto bg-white rounded-2xl shadow-2xl p-8">
            <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="text-center py-16">
                <div class="max-w-md mx-auto">
                  <div class="w-20 h-20 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6">
                    <svg class="w-10 h-10 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                  </div>
                  <h1 class="text-2xl font-bold text-gray-900 mb-4">Access Restricted</h1>
                  <p class="text-gray-600 mb-6">
                    Your account is pending administrator approval.
                    You'll gain access to team information once your roles are assigned.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What you'll see after approval:</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Your assigned team information</li>
                      <li>• Team members and collaboration tools</li>
                      <li>• Team-specific projects and resources</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Teams View -->
              <h1 class="text-3xl font-bold text-gray-800 mb-8">Teams</h1>
=======
  # Load available users when admin clicks "Add Member"
  def handle_event("show_add_member", %{"team_id" => team_id}, socket) do
    available_users = Organizations.list_users_not_in_team(team_id)
>>>>>>> Stashed changes

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
