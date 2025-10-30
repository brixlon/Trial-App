defmodule TrialAppWeb.AdminLive.UserManagement do
  use TrialAppWeb, :live_view
  import Ecto.Query, warn: false
  alias TrialApp.Accounts
  alias TrialApp.Orgs
  alias TrialApp.Repo

  def mount(_params, _session, socket) do
    users = Accounts.list_users_with_assignments()
    organizations = Orgs.list_organizations()
    teams = Orgs.list_teams() |> Repo.preload(department: [:organization])
    departments = Orgs.list_departments() |> Repo.preload([:organization])

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:organizations, organizations)
     |> assign(:teams, teams)
     |> assign(:departments, departments)
     |> assign(:filter, "all")
     |> assign(:selected_user, nil)
     |> assign(:show_edit_modal, false)
     |> assign(:user_form, %{})
     |> assign(:team_assignments, %{})
     |> assign(:available_teams, [])
     |> assign(:available_departments, [])
     |> assign(:selected_org_id, nil)
     |> assign(:selected_dept_id, nil)}
  end

  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")
    users = apply_filter(Accounts.list_users_with_assignments(), filter)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:filter, filter)}
  end

  def handle_event("edit_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user_with_assignments!(user_id)
    current_assignments = get_current_team_assignments(user)

    user_form = %{
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      status: user.status
    }

    available_teams = Orgs.list_teams() |> Repo.preload(department: [:organization])
    available_departments = Orgs.list_departments() |> Repo.preload([:organization])

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_edit_modal, true)
     |> assign(:user_form, user_form)
     |> assign(:team_assignments, current_assignments)
     |> assign(:available_teams, available_teams)
     |> assign(:available_departments, available_departments)
     |> assign(:selected_org_id, nil)
     |> assign(:selected_dept_id, nil)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:selected_user, nil)
     |> assign(:user_form, %{})
     |> assign(:team_assignments, %{})
     |> assign(:available_teams, [])
     |> assign(:available_departments, [])}
  end

  def handle_event("toggle_team_assignment", %{"team-id" => team_id}, socket) do
    current_assignments = socket.assigns.team_assignments
    team_id_str = to_string(team_id)

    new_assignments =
      if Map.has_key?(current_assignments, team_id_str) do
        Map.delete(current_assignments, team_id_str)
      else
        team = Orgs.get_team_with_employees!(team_id)

        org_name =
          if team.department && team.department.organization do
            team.department.organization.name
          else
            "Unknown Organization"
          end

        dept_name =
          if team.department do
            team.department.name
          else
            "Unknown Department"
          end

        Map.put(current_assignments, team_id_str, %{
          team_id: team.id,
          team_name: team.name,
          department_name: dept_name,
          organization_name: org_name
        })
      end

    {:noreply, assign(socket, :team_assignments, new_assignments)}
  end

  def handle_event("remove_team_assignment", %{"team-id" => team_id}, socket) do
    current_assignments = socket.assigns.team_assignments
    new_assignments = Map.delete(current_assignments, team_id)
    {:noreply, assign(socket, :team_assignments, new_assignments)}
  end

  def handle_event("select_organization", %{"filter_organization_id" => org_id}, socket) do
    org_id = if org_id == "", do: nil, else: String.to_integer(org_id)

    {available_teams, available_departments} =
      if org_id do
        teams =
          Orgs.list_teams_by_organization(org_id) |> Repo.preload(department: [:organization])

        depts = Orgs.list_departments_by_org(org_id)
        {teams, depts}
      else
        teams = Orgs.list_teams() |> Repo.preload(department: [:organization])
        depts = Orgs.list_departments()
        {teams, depts}
      end

    {:noreply,
     socket
     |> assign(:selected_org_id, org_id)
     |> assign(:selected_dept_id, nil)
     |> assign(:available_teams, available_teams)
     |> assign(:available_departments, available_departments)}
  end

  def handle_event("select_department", %{"filter_department_id" => dept_id}, socket) do
    dept_id = if dept_id == "", do: nil, else: String.to_integer(dept_id)

    available_teams =
      if dept_id do
        Orgs.list_teams_by_department(dept_id) |> Repo.preload(department: [:organization])
      else
        if socket.assigns.selected_org_id do
          Orgs.list_teams_by_organization(socket.assigns.selected_org_id)
          |> Repo.preload(department: [:organization])
        else
          Orgs.list_teams() |> Repo.preload(department: [:organization])
        end
      end

    {:noreply,
     socket
     |> assign(:selected_dept_id, dept_id)
     |> assign(:available_teams, available_teams)}
  end

  def handle_event("save_user", params, socket) do
    user = socket.assigns.selected_user

    # Extract user params (email, username, role, status)
    user_params = %{
      "email" => params["email"],
      "username" => params["username"],
      "role" => params["role"],
      "status" => params["status"]
    }

    # Extract team IDs from the form
    team_ids =
      case params["team_ids"] do
        nil -> []
        ids when is_list(ids) -> Enum.map(ids, &String.to_integer/1)
        id when is_binary(id) -> [String.to_integer(id)]
      end

    IO.inspect(user_params, label: "USER PARAMS FOR UPDATE")
    IO.inspect(team_ids, label: "TEAM IDs FOR ASSIGNMENT")

    case Accounts.update_user_with_assignments(user, user_params, team_ids) do
      {:ok, _updated_user} ->
        users = apply_filter(Accounts.list_users_with_assignments(), socket.assigns.filter)

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully!")
         |> assign(:users, users)
         |> assign(:show_edit_modal, false)
         |> assign(:selected_user, nil)
         |> assign(:user_form, %{})
         |> assign(:team_assignments, %{})
         |> assign(:available_teams, [])
         |> assign(:available_departments, [])}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "UPDATE ERROR")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to update user: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("make_admin", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_role(user, "admin") do
      {:ok, _user} ->
        users = apply_filter(Accounts.list_users_with_assignments(), socket.assigns.filter)

        {:noreply,
         socket
         |> put_flash(:info, "User promoted to admin!")
         |> assign(:users, users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to promote user to admin")}
    end
  end

  def handle_event("view_user", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    {:noreply, put_flash(socket, :info, "Viewing user #{user_id}")}
  end

  defp apply_filter(users, "all"), do: users
  defp apply_filter(users, "pending"), do: Enum.filter(users, &(&1.status == "pending"))
  defp apply_filter(users, "active"), do: Enum.filter(users, &(&1.status == "active"))

  defp user_status_class("pending"), do: "badge-warning"
  defp user_status_class("active"), do: "badge-success"
  defp user_status_class(_), do: "badge-ghost"

  defp user_status_label("pending"), do: "Pending"
  defp user_status_label("active"), do: "Active"
  defp user_status_label(_), do: "Unknown"

  defp get_current_team_assignments(user) do
    user.employees
    |> Enum.reduce(%{}, fn employee, acc ->
      team = employee.team
      dept = employee.department
      org = employee.organization

      cond do
        is_nil(employee.team_id) or is_nil(team) ->
          acc

        true ->
          team_id_str = to_string(employee.team_id)

          Map.put(acc, team_id_str, %{
            team_id: employee.team_id,
            team_name: (team && team.name) || "Unknown Team",
            department_name: (dept && dept.name) || "Unknown Department",
            organization_name: (org && org.name) || "Unknown Organization"
          })
      end
    end)
  end
end
