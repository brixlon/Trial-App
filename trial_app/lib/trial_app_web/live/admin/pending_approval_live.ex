# lib/trial_app_web/live/admin/pending_approval_live.ex
defmodule TrialAppWeb.PendingApprovalLive do
  use TrialAppWeb, :live_view

  alias TrialApp.Accounts
  alias TrialApp.Organizations

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_pending_assignment_users()
    organizations = Organizations.list_organizations()
    roles = Accounts.list_roles()
    positions = Accounts.list_positions()

    socket =
      socket
      |> stream(:users, users)
      |> assign(:organizations, organizations)
      |> assign(:roles, roles)
      |> assign(:positions, positions)
      |> assign(:dept_map, %{})
      |> assign(:team_map, %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("load_depts", %{"org_id" => org_id, "user_id" => user_id}, socket) do
    depts = if org_id == "", do: [], else: Organizations.list_departments_by_org(org_id)
    {:noreply, assign(socket, :dept_map, Map.put(socket.assigns.dept_map, user_id, depts))}
  end

  def handle_event("load_teams", %{"dept_id" => dept_id, "user_id" => user_id}, socket) do
    teams = if dept_id == "", do: [], else: Organizations.list_teams_by_dept(dept_id)
    {:noreply, assign(socket, :team_map, Map.put(socket.assigns.team_map, user_id, teams))}
  end

  def handle_event("approve", %{"user_id" => user_id} = params, socket) do
    user = Accounts.get_user!(user_id)

    attrs = %{
      organization_id: params["org_id"],
      department_id: params["dept_id"],
      team_id: params["team_id"],
      role_id: params["role_id"],
      position_id: params["position_id"],
      status: "active",
      approval_status: "APPROVED"
    }

    case Accounts.approve_and_assign_user(user, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User approved and assigned!")
         |> stream_delete(:users, user)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve user")}
    end
  end
end
