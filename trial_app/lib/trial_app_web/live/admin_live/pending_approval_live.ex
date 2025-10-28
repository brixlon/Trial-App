defmodule TrialAppWeb.AdminLive.PendingApprovalLive do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Orgs, Repo}

  def mount(params, _session, socket) do
    organizations = Orgs.list_organizations()
    user_id = params["user_id"]

    # Load the user being edited
    user = if user_id, do: Accounts.get_user!(user_id), else: nil

    {:ok,
      socket
      |> assign(:editing_user_id, user_id)
      |> assign(:editing_user, user)
      |> assign(:users, [])
      |> assign(:organizations, organizations)
      |> assign(:departments, [])
      |> assign(:teams, [])
      |> assign(:selected_org_id, nil)
      |> assign(:selected_dept_id, nil)
      |> assign(:selected_team_id, nil)
      |> assign(:roles, ["user", "manager", "admin"])
      |> assign(:form_data, %{})  # NEW: Track all form values
    }
  end

  # --- When organization changes ---
  def handle_event("select_organization", %{"user" => user_params}, socket) do
    org_id = if user_params["assigned_organization_id"] == "", do: nil, else: String.to_integer(user_params["assigned_organization_id"])
    departments = if org_id, do: Orgs.list_departments_by_org(org_id), else: []

    # Merge form data but clear department and team when org changes
    updated_form_data = Map.merge(socket.assigns.form_data, user_params)
      |> Map.put("assigned_department_id", "")
      |> Map.put("assigned_team_id", "")

    {:noreply,
      socket
      |> assign(:selected_org_id, org_id)
      |> assign(:departments, departments)
      |> assign(:teams, [])
      |> assign(:selected_dept_id, nil)
      |> assign(:selected_team_id, nil)
      |> assign(:form_data, updated_form_data)  # Store form data
    }
  end

  # --- When department changes ---
  def handle_event("select_department", %{"user" => user_params}, socket) do
    dept_id = if user_params["assigned_department_id"] == "", do: nil, else: String.to_integer(user_params["assigned_department_id"])
    teams = if dept_id, do: Orgs.list_teams_by_dept(dept_id), else: []

    # Merge form data but clear team when department changes
    updated_form_data = Map.merge(socket.assigns.form_data, user_params)
      |> Map.put("assigned_team_id", "")

    {:noreply,
      socket
      |> assign(:selected_dept_id, dept_id)
      |> assign(:teams, teams)
      |> assign(:selected_team_id, nil)
      |> assign(:form_data, updated_form_data)  # Store form data
    }
  end

  # --- NEW: Handle team selection ---
  def handle_event("select_team", %{"user" => user_params}, socket) do
    team_id = if user_params["assigned_team_id"] == "", do: nil, else: String.to_integer(user_params["assigned_team_id"])

    # Merge form data including team selection
    updated_form_data = Map.merge(socket.assigns.form_data, user_params)

    {:noreply,
      socket
      |> assign(:selected_team_id, team_id)
      |> assign(:form_data, updated_form_data)  # Store form data
    }
  end

  # --- NEW: Handle any other form field changes ---
  def handle_event("form_change", %{"user" => user_params}, socket) do
    # Merge new params with existing form data
    updated_form_data = Map.merge(socket.assigns.form_data, user_params)

    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  # --- Approve and assign user ---
  def handle_event("update_assignment", %{"user" => params}, socket) do
    IO.inspect(params, label: "FORM PARAMS RECEIVED")

    user_id = socket.assigns.editing_user_id
    user = Accounts.get_user!(user_id)

    clean_params = clean_assignment_params(params)
    IO.inspect(clean_params, label: "CLEANED PARAMS")

    # The user schema only has :role and :status fields, not the assignment fields
    # Assignment fields (organization, department, team, position) are stored in the employees table
    user_params = %{
      role: clean_params["assigned_role"] || "user",
      status: "active"  # IMPORTANT: Set status to active when approving
    }

    IO.inspect(user_params, label: "USER UPDATE PARAMS")

    # Update user with role and status
    changeset = Accounts.User.assignment_changeset(user, user_params)

    IO.inspect(changeset.valid?, label: "CHANGESET VALID?")
    IO.inspect(changeset.errors, label: "CHANGESET ERRORS")
    IO.inspect(changeset.changes, label: "CHANGESET CHANGES")

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        IO.inspect(updated_user, label: "USER UPDATED SUCCESSFULLY")
        # Create or update employee record
        case create_employee_safely(updated_user, clean_params) do
          {:ok, _emp} ->
            {:noreply,
              socket
              |> put_flash(:info, "User assigned and approved successfully!")
              |> push_navigate(to: ~p"/admin/users")}

          {:error, reason} ->
            IO.inspect(reason, label: "Employee creation error")
            {:noreply, put_flash(socket, :error, "Failed to create employee record: #{inspect(reason)}")}
        end

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "USER UPDATE FAILED")
        {:noreply, put_flash(socket, :error, "Failed to assign user: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("cancel_assignment", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/users")}
  end

  # --- Employee creation ---
  defp create_employee_safely(user, params) do
    existing = Accounts.get_employee_by_user_id(user.id)

    team_id = params["assigned_team_id"]
    department_id = params["assigned_department_id"]
    organization_id = params["assigned_organization_id"]
    position = params["assigned_position"]
    role = params["assigned_role"]

    # Determine department_id - use selected department, or infer from team
    inferred_dept_id =
      cond do
        department_id -> department_id
        team_id ->
          case Orgs.get_team!(team_id) do
            %{department_id: dept_id} -> dept_id
            _ -> nil
          end
        true -> nil
      end

    # Determine organization_id - use selected org, or infer from department
    inferred_org_id =
      cond do
        organization_id -> organization_id
        inferred_dept_id ->
          case Orgs.get_department!(inferred_dept_id) do
            %{organization_id: org_id} -> org_id
            _ -> nil
          end
        true -> nil
      end

    # FIX: If no team is selected, find or create a default team to avoid NULL constraint
    final_team_id = if team_id do
      team_id
    else
      find_or_create_default_team(inferred_dept_id, inferred_org_id)
    end

    attrs = %{
      user_id: user.id,
      name: user.username || user.email,
      email: user.email,
      team_id: final_team_id,  # Now this will never be null
      department_id: inferred_dept_id,
      organization_id: inferred_org_id,
      role: role || "user",
      position: position || "Employee"
    }

    IO.inspect(attrs, label: "EMPLOYEE ATTRS")

    case existing do
      nil ->
        Accounts.create_employee(attrs)
      emp ->
        Accounts.update_employee(emp, attrs)
    end
  end

  defp find_or_create_default_team(department_id, organization_id) do
    # Try to find an existing "General" team in the department
    if department_id do
      teams = Orgs.list_teams_by_dept(department_id)
      general_team = Enum.find(teams, &(&1.name == "General"))

      if general_team do
        general_team.id
      else
        # Create a new "General" team
        case Orgs.create_team(%{name: "General", department_id: department_id}) do
          {:ok, team} -> team.id
          {:error, _} -> find_any_team_in_organization(organization_id)
        end
      end
    else
      find_any_team_in_organization(organization_id)
    end
  end

  defp find_any_team_in_organization(organization_id) do
    if organization_id do
      # Get any team in the organization
      departments = Orgs.list_departments_by_org(organization_id)

      Enum.find_value(departments, fn dept ->
        teams = Orgs.list_teams_by_dept(dept.id)
        if Enum.any?(teams), do: hd(teams).id
      end)
    else
      # Last resort: get the first team in the database
      teams = Orgs.list_teams()
      if Enum.any?(teams), do: hd(teams).id, else: create_fallback_team()
    end
  end

  defp create_fallback_team() do
    # Create a fallback team if no teams exist
    orgs = Orgs.list_organizations()
    depts = Orgs.list_departments()

    department_id = if Enum.any?(depts), do: hd(depts).id, else: create_fallback_department(orgs)

    case Orgs.create_team(%{name: "Default Team", department_id: department_id}) do
      {:ok, team} -> team.id
      {:error, _} -> raise "Could not create fallback team - please check your database"
    end
  end

  defp create_fallback_department(orgs) do
    organization_id = if Enum.any?(orgs), do: hd(orgs).id, else: create_fallback_organization()

    case Orgs.create_department(%{name: "Default Department", organization_id: organization_id}) do
      {:ok, dept} -> dept.id
      {:error, _} -> raise "Could not create fallback department - please check your database"
    end
  end

  defp create_fallback_organization() do
    case Orgs.create_organization(%{name: "Default Organization"}) do
      {:ok, org} -> org.id
      {:error, _} -> raise "No organizations exist and cannot create one - please seed your database"
    end
  end

  defp clean_assignment_params(params) do
    params
    |> Map.update("assigned_organization_id", nil, &to_nil_or_int/1)
    |> Map.update("assigned_department_id", nil, &to_nil_or_int/1)
    |> Map.update("assigned_team_id", nil, &to_nil_or_int/1)
    |> Map.update("assigned_position", nil, &empty_to_nil/1)
    |> Map.update("assigned_role", nil, &empty_to_nil/1)
  end

  defp to_nil_or_int(""), do: nil
  defp to_nil_or_int(val) when is_binary(val), do: String.to_integer(val)
  defp to_nil_or_int(val), do: val

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(val), do: val

  # --- Render Form ---
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">Assign and Approve User</h1>

      <%= if @editing_user do %>
        <div class="mb-4 p-4 bg-gray-100 rounded">
          <p><strong>User:</strong> <%= @editing_user.email %></p>
          <p><strong>Username:</strong> <%= @editing_user.username || "Not set" %></p>
        </div>

        <form phx-change="form_change" phx-submit="update_assignment" class="mt-6 p-4 border rounded">
          <h3 class="text-lg font-semibold mb-4">Assign to Organization</h3>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">

            <!-- Organization -->
            <div>
              <label class="block text-sm font-medium mb-1">Organization *</label>
              <select name="user[assigned_organization_id]"
                      phx-change="select_organization"
                      value={@form_data["assigned_organization_id"] || ""}
                      class="select select-bordered w-full"
                      required>
                <option value="">Select Organization</option>
                <%= for org <- @organizations do %>
                  <option value={org.id} selected={@selected_org_id == org.id}><%= org.name %></option>
                <% end %>
              </select>
            </div>

            <!-- Role -->
            <div>
              <label class="block text-sm font-medium mb-1">Role *</label>
              <select name="user[assigned_role]"
                      value={@form_data["assigned_role"] || ""}
                      class="select select-bordered w-full"
                      required>
                <option value="">Select Role</option>
                <%= for role <- @roles do %>
                  <option value={role}><%= String.capitalize(role) %></option>
                <% end %>
              </select>
            </div>

            <!-- Department -->
            <div>
              <label class="block text-sm font-medium mb-1">Department</label>
              <select name="user[assigned_department_id]"
                      phx-change="select_department"
                      value={@form_data["assigned_department_id"] || ""}
                      class="select select-bordered w-full"
                      disabled={@departments == []}>
                <option value="">Select Department</option>
                <%= for dept <- @departments do %>
                  <option value={dept.id} selected={@selected_dept_id == dept.id}><%= dept.name %></option>
                <% end %>
              </select>
            </div>

            <!-- Team -->
            <div>
              <label class="block text-sm font-medium mb-1">Team</label>
              <select name="user[assigned_team_id]"
                      phx-change="select_team"
                      value={@form_data["assigned_team_id"] || ""}
                      class="select select-bordered w-full"
                      disabled={@selected_dept_id == nil}>
                <option value="">Select Team</option>
                <%= for team <- @teams do %>
                  <option value={team.id} selected={@selected_team_id == team.id}><%= team.name %></option>
                <% end %>
              </select>
              <%= if @teams == [] and @selected_dept_id != nil do %>
                <p class="text-xs text-gray-500 mt-1">No teams available in this department</p>
              <% end %>
            </div>

            <!-- Position -->
            <div class="md:col-span-2">
              <label class="block text-sm font-medium mb-1">Position</label>
              <input type="text"
                     name="user[assigned_position]"
                     value={@form_data["assigned_position"] || ""}
                     class="input input-bordered w-full"
                     placeholder="e.g., Software Engineer, Marketing Manager, etc." />
            </div>
          </div>

          <div class="mt-6 flex space-x-2">
            <button type="submit" class="btn btn-primary">Save & Approve User</button>
            <button type="button" class="btn btn-secondary" phx-click="cancel_assignment">Cancel</button>
          </div>
        </form>
      <% else %>
        <div class="alert alert-warning">
          <p>No user selected for approval.</p>
          <a href={~p"/admin/users"} class="btn btn-sm btn-outline mt-2">Go to User Management</a>
        </div>
      <% end %>
    </div>
    """
  end
end
