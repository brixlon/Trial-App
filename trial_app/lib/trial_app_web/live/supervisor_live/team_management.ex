defmodule TrialAppWeb.SupervisorLive.TeamManagement do
  use TrialAppWeb, :live_view
  import Ecto.Query
  alias TrialApp.{Orgs, Accounts, Repo}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Get departments where user is supervisor
    departments = Orgs.list_departments_for_supervisor(current_user.id)

    # Get all teams in supervised departments
    teams = if Enum.any?(departments) do
      department_ids = Enum.map(departments, & &1.id)
      from(t in Orgs.Team,
        where: t.department_id in ^department_ids and t.is_active == true,
        preload: [:department, :organization, :team_lead, :employees]
      )
      |> Repo.all()
    else
      []
    end

    # Get all employees in supervised departments
    employees = if Enum.any?(departments) do
      department_ids = Enum.map(departments, & &1.id)
      from(e in Orgs.Employee,
        where: e.department_id in ^department_ids and e.is_active == true,
        preload: [:user, :team, :department]
      )
      |> Repo.all()
    else
      []
    end

    # Get all users for team lead assignment
    users = Accounts.list_users()

    {:ok,
     socket
     |> assign(:departments, departments)
     |> assign(:teams, teams)
     |> assign(:employees, employees)
     |> assign(:users, users)
     |> assign(:team_members, [])
     |> assign(:show_team_form, false)
     |> assign(:show_move_employee_modal, false)
     |> assign(:selected_employee, nil)
     |> assign(:team_form_data, %{name: "", description: "", department_id: "", team_lead_id: ""})
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_event("new_team", _params, socket) do
    # For new teams, no team members exist yet
    {:noreply,
     socket
     |> assign(:show_team_form, true)
     |> assign(:editing_team, nil)
     |> assign(:team_members, [])
     |> assign(:team_form_data, %{
       name: "",
       description: "",
       department_id: if(Enum.any?(socket.assigns.departments), do: to_string(List.first(socket.assigns.departments).id), else: ""),
       team_lead_id: ""
     })
     |> assign(:errors, %{})}
  end

  def handle_event("edit_team", %{"id" => id}, socket) do
    team = Orgs.get_team!(String.to_integer(id)) |> Repo.preload([:team_lead, :employees])

    # Only show users who are members of this team
    team_members =
      Orgs.list_employees_by_team(team.id)
      |> Enum.map(fn employee -> employee.user end)
      |> Enum.filter(&(!is_nil(&1)))
      |> Enum.uniq_by(& &1.id)

    {:noreply,
     socket
     |> assign(:show_team_form, true)
     |> assign(:editing_team, team)
     |> assign(:team_members, team_members)
     |> assign(:team_form_data, %{
       name: team.name,
       description: team.description || "",
       department_id: to_string(team.department_id),
       team_lead_id: if(team.team_lead_id, do: to_string(team.team_lead_id), else: "")
     })
     |> assign(:errors, %{})}
  end

  def handle_event("cancel_team_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_team_form, false)
     |> assign(:editing_team, nil)
     |> assign(:team_members, [])
     |> assign(:team_form_data, %{name: "", description: "", department_id: "", team_lead_id: ""})
     |> assign(:errors, %{})}
  end

  def handle_event("update_team_form", %{"team" => params}, socket) do
    form_data = Map.merge(socket.assigns.team_form_data, params)
    {:noreply, assign(socket, :team_form_data, form_data)}
  end

  def handle_event("save_team", %{"team" => params}, socket) do
    {name, description, department_id, team_lead_id} = {
      params["name"],
      params["description"] || "",
      params["department_id"],
      params["team_lead_id"] || ""
    }

    errors = %{}
    errors = if String.trim(name) == "", do: Map.put(errors, :name, "Team name is required"), else: errors
    errors = if String.trim(department_id) == "", do: Map.put(errors, :department_id, "Department is required"), else: errors

    if map_size(errors) == 0 do
      department = Orgs.get_department!(String.to_integer(department_id))
      team_lead_id_int = if team_lead_id != "" && team_lead_id != nil, do: String.to_integer(team_lead_id), else: nil

      team_params = %{
        name: name,
        description: description,
        department_id: String.to_integer(department_id),
        organization_id: department.organization_id,
        team_lead_id: team_lead_id_int
      }

      result = if socket.assigns[:editing_team] do
        Orgs.update_team(socket.assigns.editing_team, team_params)
      else
        Orgs.create_team(team_params)
      end

      case result do
        {:ok, _team} ->
          # Refresh teams
          department_ids = Enum.map(socket.assigns.departments, & &1.id)
          teams = from(t in TrialApp.Orgs.Team,
            where: t.department_id in ^department_ids and t.is_active == true,
            preload: [:department, :organization, :team_lead, :employees]
          )
          |> Repo.all()

          {:noreply,
           socket
           |> assign(:teams, teams)
           |> assign(:show_team_form, false)
           |> assign(:editing_team, nil)
           |> assign(:team_form_data, %{name: "", description: "", department_id: "", team_lead_id: ""})
           |> assign(:errors, %{})
           |> put_flash(:info, "Team #{if socket.assigns[:editing_team], do: "updated", else: "created"} successfully!")}

        {:error, changeset} ->
          errors = traverse_errors(changeset)
          {:noreply, assign(socket, :errors, errors)}
      end
    else
      {:noreply, assign(socket, :errors, errors)}
    end
  end

  def handle_event("delete_team", %{"id" => id}, socket) do
    team = Orgs.get_team!(String.to_integer(id))

    case Orgs.delete_team(team) do
      {:ok, _team} ->
        department_ids = Enum.map(socket.assigns.departments, & &1.id)
        teams = from(t in TrialApp.Orgs.Team,
          where: t.department_id in ^department_ids and t.is_active == true,
          preload: [:department, :organization, :team_lead, :employees]
        )
        |> Repo.all()

        {:noreply,
         socket
         |> assign(:teams, teams)
         |> put_flash(:info, "Team deleted successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete team")}
    end
  end

  def handle_event("move_employee", %{"id" => employee_id}, socket) do
    employee = Orgs.get_employee!(String.to_integer(employee_id)) |> Repo.preload([:user, :team, :department])

    # Get available teams in the same department
    available_teams = from(t in TrialApp.Orgs.Team,
      where: t.department_id == ^employee.department_id and t.is_active == true,
      preload: [:department]
    )
    |> Repo.all()

    {:noreply,
     socket
     |> assign(:show_move_employee_modal, true)
     |> assign(:selected_employee, employee)
     |> assign(:available_teams, available_teams)
     |> assign(:target_team_id, "")}
  end

  def handle_event("cancel_move_employee", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_move_employee_modal, false)
     |> assign(:selected_employee, nil)
     |> assign(:target_team_id, "")}
  end

  def handle_event("update_target_team", %{"value" => team_id}, socket) do
    {:noreply, assign(socket, :target_team_id, team_id)}
  end

  def handle_event("confirm_move_employee", %{"team_id" => team_id}, socket) do
    employee = socket.assigns.selected_employee
    target_team = Orgs.get_team!(String.to_integer(team_id)) |> Repo.preload(:department)

    case Orgs.update_employee(employee, %{
      team_id: target_team.id,
      department_id: target_team.department_id,
      organization_id: target_team.department.organization_id
    }) do
      {:ok, _employee} ->
        # Refresh employees
        department_ids = Enum.map(socket.assigns.departments, & &1.id)
        employees = from(e in Orgs.Employee,
          where: e.department_id in ^department_ids and e.is_active == true,
          preload: [:user, :team, :department]
        )
        |> Repo.all()

        # Refresh teams
        teams = from(t in TrialApp.Orgs.Team,
          where: t.department_id in ^department_ids and t.is_active == true,
          preload: [:department, :organization, :team_lead, :employees]
        )
        |> Repo.all()

        {:noreply,
         socket
         |> assign(:employees, employees)
         |> assign(:teams, teams)
         |> assign(:show_move_employee_modal, false)
         |> assign(:selected_employee, nil)
         |> assign(:target_team_id, "")
         |> put_flash(:info, "Employee moved to #{target_team.name} successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to move employee")}
    end
  end

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Team Management</h1>
          <p class="text-gray-600 mt-2">Manage teams and employees in your supervised departments</p>
        </div>
        <%= if Enum.any?(@departments) do %>
          <button
            phx-click="new_team"
            class="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 font-semibold"
          >
            + New Team
          </button>
        <% else %>
          <p class="text-gray-500">You are not assigned as a supervisor for any departments.</p>
        <% end %>
      </div>

      <%= if Enum.empty?(@departments) do %>
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 text-center">
          <p class="text-yellow-800">
            You are not assigned as a supervisor for any departments.
          </p>
        </div>
      <% else %>
        <!-- Team Form -->
        <%= if @show_team_form do %>
          <.team_form
            form_data={@team_form_data}
            departments={@departments}
            users={@users}
            errors={@errors}
            editing={!is_nil(@editing_team)}
          />
        <% end %>

        <!-- Teams List -->
        <div class="bg-white rounded-lg shadow overflow-hidden mb-6">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-xl font-semibold text-gray-900">Teams</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Department</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Team Lead</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Members</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for team <- @teams do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= team.name %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= team.department.name %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= if team.team_lead do %>
                        <%= "#{team.team_lead.first_name || ""} #{team.team_lead.last_name || ""}" |> String.trim() %>
                      <% else %>
                        <span class="text-gray-400">No team lead</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= length(team.employees || []) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                      <button
                        phx-click="edit_team"
                        phx-value-id={team.id}
                        class="text-blue-600 hover:text-blue-900"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete_team"
                        phx-value-id={team.id}
                        onclick="return confirm('Are you sure?')"
                        class="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                <% end %>
                <%= if Enum.empty?(@teams) do %>
                  <tr>
                    <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                      No teams yet. Create your first team!
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Employees List -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-xl font-semibold text-gray-900">Employees</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Current Team</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Department</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for employee <- @employees do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= employee.user.first_name || "" %> <%= employee.user.last_name || "" %> |> String.trim()
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= employee.user.email %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= if employee.team, do: employee.team.name, else: "No team" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= employee.department.name %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button
                        phx-click="move_employee"
                        phx-value-id={employee.id}
                        class="text-indigo-600 hover:text-indigo-900"
                      >
                        Move to Another Team
                      </button>
                    </td>
                  </tr>
                <% end %>
                <%= if Enum.empty?(@employees) do %>
                  <tr>
                    <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                      No employees in your supervised departments.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Move Employee Modal -->
        <%= if @show_move_employee_modal && @selected_employee do %>
          <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div class="bg-white rounded-xl shadow-2xl w-full max-w-md">
              <div class="p-6 border-b border-gray-200 flex justify-between items-center">
                <h2 class="text-2xl font-bold text-gray-900">Move Employee</h2>
                <button
                  phx-click="cancel_move_employee"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <div class="p-6 space-y-4">
                <div>
                  <p class="text-sm text-gray-600 mb-4">
                    Move <strong><%= "#{@selected_employee.user.first_name || ""} #{@selected_employee.user.last_name || ""}" |> String.trim() %></strong>
                    from <strong><%= if @selected_employee.team, do: @selected_employee.team.name, else: "No team" %></strong>
                    to:
                  </p>
                  <select
                    phx-change="update_target_team"
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
                  >
                    <option value="">Select a team</option>
                    <%= for team <- @available_teams do %>
                      <option value={team.id} selected={to_string(team.id) == @target_team_id}>
                        <%= team.name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div class="flex justify-end gap-3 pt-4 border-t">
                  <button
                    phx-click="cancel_move_employee"
                    class="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    phx-click="confirm_move_employee"
                    phx-value-team_id={@target_team_id}
                    disabled={@target_team_id == ""}
                    class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
                  >
                    Move Employee
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp team_form(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
      <h2 class="text-2xl font-bold mb-4">
        <%= if @editing, do: "Edit Team", else: "New Team" %>
      </h2>

      <form phx-submit="save_team" phx-change="update_team_form" class="space-y-6">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Team Name *</label>
          <input
            type="text"
            name="team[name]"
            value={@form_data.name}
            required
            placeholder="e.g., Frontend Team, Sales Team"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          />
          <%= if @errors[:name] do %>
            <p class="mt-1 text-sm text-red-600">{@errors[:name]}</p>
          <% end %>
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">Description</label>
          <textarea
            name="team[description]"
            rows="3"
            placeholder="Brief description of this team's purpose..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          ><%= @form_data.description %></textarea>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-2">Department *</label>
            <select
              name="team[department_id]"
              value={@form_data.department_id}
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
            >
              <option value="">Select a department</option>
              <%= for dept <- @departments do %>
                <option value={dept.id} selected={to_string(dept.id) == @form_data.department_id}>
                  <%= dept.name %>
                </option>
              <% end %>
            </select>
            <%= if @errors[:department_id] do %>
              <p class="mt-1 text-sm text-red-600">{@errors[:department_id]}</p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-2">Team Lead</label>
            <select
              name="team[team_lead_id]"
              value={@form_data.team_lead_id}
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
            >
              <option value="">Select a team lead (optional)</option>
              <%= if @editing_team && length(@team_members) > 0 do %>
                <%= for user <- @team_members do %>
                  <option value={user.id} selected={to_string(user.id) == @form_data.team_lead_id}>
                    <%= "#{user.first_name || ""} #{user.last_name || ""}" |> String.trim() %> (<%= user.email %>)
                  </option>
                <% end %>
              <% else %>
                <option value="" disabled>No team members available. Add members to the team first.</option>
              <% end %>
            </select>
            <p class="mt-1 text-xs text-gray-500">
              <%= if @editing_team do %>
                Team lead must be selected from existing team members
              <% else %>
                Team lead can be assigned after team members are added
              <% end %>
            </p>
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t">
          <button
            type="button"
            phx-click="cancel_team_form"
            class="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <%= if @editing, do: "Update Team", else: "Create Team" %>
          </button>
        </div>
      </form>
    </div>
    """
  end
end
