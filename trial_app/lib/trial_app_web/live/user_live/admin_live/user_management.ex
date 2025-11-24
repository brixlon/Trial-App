defmodule TrialAppWeb.AdminLive.UserManagement do
  use TrialAppWeb, :live_view
  import Ecto.Query, warn: false
  alias TrialApp.Accounts
  alias TrialApp.Orgs
  alias TrialApp.Repo
  import TrialAppWeb.Live.Helpers.RoleSwitcher

  @impl true
  def handle_info({:switch_role, new_role}, socket), do: handle_role_switch(socket, new_role)

  def mount(_params, _session, socket) do
    # Fetch ALL users, not just employees
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
     |> assign(:role_filter, "all")
     |> assign(:search_query, "")
     |> assign(:selected_user, nil)
     |> assign(:show_edit_modal, false)
     |> assign(:show_add_modal, false)
     |> assign(:show_view_modal, false)
     |> assign(:show_delete_modal, false)
     |> assign(:user_form, %{})
     |> assign(:team_assignments, %{})
     |> assign(:available_teams, [])
     |> assign(:available_departments, [])
     |> assign(:selected_org_id, nil)
     |> assign(:selected_dept_id, nil)}
  end

  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")
    role_filter = Map.get(params, "role", "all")

    all_users = Accounts.list_users_with_assignments()
    filtered_users =
      all_users
      |> apply_filter(filter)
      |> apply_role_filter(role_filter)
      |> apply_search(socket.assigns.search_query)

    {:noreply,
     socket
     |> assign(:users, filtered_users)
     |> assign(:filter, filter)
     |> assign(:role_filter, role_filter)}
  end

  def handle_event("open_add_modal", _, socket) do
    user_form = %{
      "email" => "",
      "first_name" => "",
      "last_name" => "",
      "phone_number" => ""
    }

    {:noreply,
     socket
     |> assign(:show_add_modal, true)
     |> assign(:user_form, user_form)}
  end

  def handle_event("update_form_field", params, socket) do
    field = params["field"]
    value = params["value"] || Map.get(params, field, "")
    user_form = Map.put(socket.assigns.user_form, field, value)
    {:noreply, assign(socket, :user_form, user_form)}
  end

  def handle_event("create_user", params, socket) do
    roles =
      case params["roles"] do
        nil -> ["employee"]
        roles when is_list(roles) -> roles
        role when is_binary(role) -> [role]
      end

    user_params = %{
      "email" => params["email"],
      "first_name" => params["first_name"],
      "last_name" => params["last_name"],
      "phone_number" => params["phone_number"],
      "roles" => roles,
      "status" => params["status"] || "pending"
    }

    case Accounts.create_user(user_params) do
      {:ok, _new_user} ->
        users =
          Accounts.list_users_with_assignments()
          |> apply_filter(socket.assigns.filter)
          |> apply_role_filter(socket.assigns.role_filter)
          |> apply_search(socket.assigns.search_query)

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully!")
         |> assign(:users, users)
         |> assign(:show_add_modal, false)
         |> assign(:user_form, %{})}

      {:error, changeset} ->
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create user: #{error_message}")}
    end
  end

  def handle_event("edit_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user_with_assignments!(user_id)
    current_assignments = get_current_team_assignments(user)

    # Support multiple roles as checkboxes
    user_roles = user.roles || []

    user_form = %{
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      roles: user_roles,
      status: user.status,
      # Track which roles are selected
      is_attachee: "attachee" in user_roles,
      is_supervisor: "supervisor" in user_roles,
      is_admin: "admin" in user_roles
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

  def handle_event("view_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user_with_assignments!(user_id)
    current_assignments = get_current_team_assignments(user)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_view_modal, true)
     |> assign(:team_assignments, current_assignments)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    all_users = Accounts.list_users_with_assignments()
    filtered_users =
      all_users
      |> apply_filter(socket.assigns.filter)
      |> apply_role_filter(socket.assigns.role_filter)
      |> apply_search(query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:users, filtered_users)}
  end

  def handle_event("confirm_delete_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_delete_modal, true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:show_add_modal, false)
     |> assign(:show_view_modal, false)
     |> assign(:show_delete_modal, false)
     |> assign(:selected_user, nil)
     |> assign(:user_form, %{})
     |> assign(:team_assignments, %{})}
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

    # Build roles array from checkboxes
    roles = []
    roles = if params["is_attachee"] == "true", do: ["attachee" | roles], else: roles
    roles = if params["is_supervisor"] == "true", do: ["supervisor" | roles], else: roles
    roles = if params["is_admin"] == "true", do: ["admin" | roles], else: roles

    # Set primary role to first selected role, or "user" if none selected
    primary_role = List.first(roles) || "user"

    # Extract user params (email, username, roles, status)
    user_params = %{
      "email" => params["email"],
      "username" => params["username"],
      "role" => primary_role,
      "roles" => roles,
      "status" => params["status"]
    }

    team_ids =
      case params["team_ids"] do
        nil -> []
        ids when is_list(ids) -> Enum.map(ids, &String.to_integer/1)
        id when is_binary(id) -> [String.to_integer(id)]
      end

    attachee? = params["is_attachee"] == "true"

    attachee_dates = %{
      "starts_on" => Map.get(params, "attachee_starts_on"),
      "ends_on" => Map.get(params, "attachee_ends_on")
    }

    case Accounts.update_user_with_assignments(user, user_params, team_ids, %{
           attachee?: attachee?,
           attachee_dates: attachee_dates
         }) do
      {:ok, _updated_user} ->
        users =
          Accounts.list_users_with_assignments()
          |> apply_filter(socket.assigns.filter)
          |> apply_role_filter(socket.assigns.role_filter)
          |> apply_search(socket.assigns.search_query)

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
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update user: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("make_admin", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_role(user, "admin") do
      {:ok, _user} ->
        users =
          Accounts.list_users_with_assignments()
          |> apply_filter(socket.assigns.filter)
          |> apply_role_filter(socket.assigns.role_filter)
          |> apply_search(socket.assigns.search_query)

        {:noreply,
         socket
         |> put_flash(:info, "User promoted to admin!")
         |> assign(:users, users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to promote user to admin")}
    end
  end

  def handle_event("delete_user", _, socket) do
    user = socket.assigns.selected_user

    case Accounts.delete_user(user) do
      {:ok, _user} ->
        all_users = Accounts.list_users_with_assignments()
        filtered_users =
          all_users
          |> apply_filter(socket.assigns.filter)
          |> apply_role_filter(socket.assigns.role_filter)
          |> apply_search(socket.assigns.search_query)

        {:noreply,
         socket
         |> put_flash(:info, "User deleted successfully!")
         |> assign(:users, filtered_users)
         |> assign(:show_view_modal, false)
         |> assign(:show_edit_modal, false)
         |> assign(:show_delete_modal, false)
         |> assign(:selected_user, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end

  # Filter functions
  defp apply_filter(users, "all"), do: users
  defp apply_filter(users, "pending"), do: Enum.filter(users, &(&1.status == "pending"))
  defp apply_filter(users, "active"), do: Enum.filter(users, &(&1.status == "active"))
  defp apply_filter(users, _), do: users

  defp apply_role_filter(users, "all"), do: users
  defp apply_role_filter(users, "employee"), do: Enum.filter(users, &has_role?(&1, "employee"))
  defp apply_role_filter(users, "attachee"), do: Enum.filter(users, &has_role?(&1, "attachee"))
  defp apply_role_filter(users, "supervisor"), do: Enum.filter(users, &has_role?(&1, "supervisor"))
  defp apply_role_filter(users, "admin"), do: Enum.filter(users, &has_role?(&1, "admin"))
  defp apply_role_filter(users, _), do: users

  defp has_role?(user, role) do
    Enum.member?(user.roles || [], role)
  end

  defp apply_search(users, ""), do: users
  defp apply_search(users, query) do
    query_lower = String.downcase(query)

    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.username || ""), query_lower) ||
        String.contains?(String.downcase(user.email || ""), query_lower)
    end)
  end

  defp user_status_class("pending"), do: "badge-warning"
  defp user_status_class("active"), do: "badge-success"
  defp user_status_class(_), do: "badge-ghost"

  defp user_status_label("pending"), do: "Pending"
  defp user_status_label("active"), do: "Active"
  defp user_status_label(_), do: "Unknown"

  defp role_badge_class("admin"), do: "badge-error"
  defp role_badge_class("supervisor"), do: "badge-info"
  defp role_badge_class("attachee"), do: "badge-warning"
  defp role_badge_class("employee"), do: "badge-primary"
  defp role_badge_class(_), do: "badge-ghost"

  defp role_label("admin"), do: "Admin"
  defp role_label("supervisor"), do: "Supervisor"
  defp role_label("attachee"), do: "Attachee"
  defp role_label("employee"), do: "Employee"
  defp role_label(role), do: String.capitalize(role)

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

  defp role_badge_color("attachee"), do: "bg-blue-100 text-blue-800"
  defp role_badge_color("supervisor"), do: "bg-green-100 text-green-800"
  defp role_badge_color("admin"), do: "bg-purple-100 text-purple-800"
  defp role_badge_color(_), do: "bg-gray-100 text-gray-800"
end
