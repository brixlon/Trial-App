defmodule TrialAppWeb.AdminLive.UserManagement do
  use TrialAppWeb, :live_view
  import Ecto.Query, warn: false
  alias TrialApp.Accounts
  alias TrialApp.Orgs
  alias TrialApp.Repo
  alias TrialApp.Orgs.{Employee, Organization, Department, Team}

  def mount(_params, _session, socket) do
    users = Accounts.list_users_with_assignments()
    organizations = Orgs.list_organizations()
    teams = Orgs.list_teams() |> Repo.preload([department: [:organization]])
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

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto">
            <!-- Header -->
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-gray-900">User Management</h1>
              <p class="text-gray-600 mt-2">Manage user accounts, roles, and team assignments</p>
            </div>

            <!-- Filter Tabs -->
            <div class="mb-6">
              <div class="border-b border-gray-200">
                <nav class="-mb-px flex space-x-8">
                  <.link
                    patch={~p"/admin/users?filter=all"}
                    class={[
                      "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm",
                      @filter == "all" && "border-blue-500 text-blue-600",
                      @filter != "all" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    All Users
                    <span class="ml-2 bg-gray-100 text-gray-900 py-0.5 px-2 rounded-full text-xs">
                      <%= Enum.count(@users) %>
                    </span>
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=pending"}
                    class={[
                      "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm",
                      @filter == "pending" && "border-yellow-500 text-yellow-600",
                      @filter != "pending" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Pending Approval
                    <span class="ml-2 bg-yellow-100 text-yellow-800 py-0.5 px-2 rounded-full text-xs">
                      <%= Enum.count(@users, &(&1.status == "pending")) %>
                    </span>
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=active"}
                    class={[
                      "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm",
                      @filter == "active" && "border-green-500 text-green-600",
                      @filter != "active" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Active Users
                    <span class="ml-2 bg-green-100 text-green-800 py-0.5 px-2 rounded-full text-xs">
                      <%= Enum.count(@users, &(&1.status == "active")) %>
                    </span>
                  </.link>
                </nav>
              </div>
            </div>

            <!-- Users Table -->
            <div class="bg-white border border-gray-200 rounded-lg shadow-sm">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      User
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Role
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Teams
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Registered
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for user <- @users do %>
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex items-center">
                          <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                            <span class="text-blue-600 font-semibold text-sm">
                              <%= String.at(user.username, 0) |> String.upcase() %>
                            </span>
                          </div>
                          <div>
                            <div class="text-sm font-medium text-gray-900">
                              <%= user.username %>
                            </div>
                            <div class="text-sm text-gray-500">
                              <%= user.email %>
                            </div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                          user_status_class(user.status)
                        ]}>
                          <%= user_status_label(user.status) %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= String.capitalize(user.role) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= if Enum.any?(user.employees) do %>
                          <div class="flex flex-wrap gap-1">
                            <%= for employee <- Enum.take(user.employees, 3) do %>
                              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800">
                                <%= employee.team.name %>
                              </span>
                            <% end %>
                            <%= if Enum.count(user.employees) > 3 do %>
                              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs bg-gray-100 text-gray-600">
                                +<%= Enum.count(user.employees) - 3 %> more
                              </span>
                            <% end %>
                          </div>
                        <% else %>
                          <span class="text-gray-400">No teams</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= Timex.format!(user.inserted_at, "{M}/{D}/{YYYY}") %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <%= if user.status == "pending" do %>
                          <.link
                            navigate={~p"/admin/pending-approvals?user_id=#{user.id}"}
                            class="text-green-600 hover:text-green-900 mr-3"
                          >
                            Approve
                          </.link>
                        <% end %>

                        <%= if user.status == "active" && user.role == "user" do %>
                          <button
                            phx-click="make_admin"
                            phx-value-user-id={user.id}
                            class="text-purple-600 hover:text-purple-900 mr-3"
                          >
                            Make Admin
                          </button>
                        <% end %>

                        <button
                          phx-click="edit_user"
                          phx-value-user-id={user.id}
                          class="text-blue-600 hover:text-blue-900 mr-3"
                        >
                          Edit
                        </button>

                        <button
                          phx-click="view_user"
                          phx-value-user-id={user.id}
                          class="text-gray-600 hover:text-gray-900"
                        >
                          View
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@users) do %>
                <div class="text-center py-12">
                  <svg class="w-12 h-12 mx-auto text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 11-5 0 2.5 2.5 0 015 0z"/>
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No users found</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    <%= if @filter == "pending" do %>
                      No users are waiting for approval.
                    <% else %>
                      Get started by creating a new user.
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>

      <!-- Edit User Modal -->
      <%= if @show_edit_modal && @selected_user do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div class="relative top-20 mx-auto p-5 border w-full max-w-4xl shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex justify-between items-center pb-4 border-b">
                <h3 class="text-lg font-medium text-gray-900">
                  Edit User: <%= @selected_user.username %>
                </h3>
                <button
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <!-- User Edit Form -->
              <form phx-submit="save_user" class="mt-4 space-y-6">
                <!-- Basic Information -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Email</label>
                    <input
                      type="email"
                      name="email"
                      value={@user_form[:email]}
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Username</label>
                    <input
                      type="text"
                      name="username"
                      value={@user_form[:username]}
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                  </div>
                </div>

                <!-- Role and Status -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Role</label>
                    <select
                      name="role"
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="user" selected={@user_form[:role] == "user"}>User</option>
                      <option value="manager" selected={@user_form[:role] == "manager"}>Manager</option>
                      <option value="admin" selected={@user_form[:role] == "admin"}>Admin</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Status</label>
                    <select
                      name="status"
                      class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="pending" selected={@user_form[:status] == "pending"}>Pending</option>
                      <option value="active" selected={@user_form[:status] == "active"}>Active</option>
                      <option value="suspended" selected={@user_form[:status] == "suspended"}>Suspended</option>
                    </select>
                  </div>
                </div>

                <!-- Team Assignments -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-3">Team Assignments</label>

                  <!-- Organization Filter -->
                  <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Filter by Organization</label>
                    <select
                      phx-change="select_organization"
                      name="filter_organization_id"
                      class="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">All Organizations</option>
                      <%= for org <- @organizations do %>
                        <option value={org.id} selected={@selected_org_id == org.id}><%= org.name %></option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Department Filter -->
                  <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Filter by Department</label>
                    <select
                      phx-change="select_department"
                      name="filter_department_id"
                      class="block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">All Departments</option>
                      <%= for dept <- @available_departments do %>
                        <option value={dept.id} selected={@selected_dept_id == dept.id}>
                          <%= dept.name %> - <%= dept.organization.name %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Teams Grid -->
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 max-h-64 overflow-y-auto p-2 border border-gray-200 rounded-md">
                    <%= for team <- @available_teams do %>
                      <div class="flex items-start">
                        <input
                          type="checkbox"
                          id={"team_#{team.id}"}
                          name={"team_assignment[#{team.id}]"}
                          value="true"
                          checked={Map.has_key?(@team_assignments, to_string(team.id))}
                          phx-click="toggle_team_assignment"
                          phx-value-team-id={team.id}
                          class="h-4 w-4 mt-1 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                        />
                        <label for={"team_#{team.id}"} class="ml-2 text-sm text-gray-700">
                          <div class="font-medium"><%= team.name %></div>
                          <div class="text-gray-500 text-xs">
                            <%= team.department.name %> - <%= team.department.organization.name %>
                          </div>
                        </label>
                      </div>
                    <% end %>
                    <%= if Enum.empty?(@available_teams) do %>
                      <div class="col-span-full text-center py-8 text-gray-500">
                        No teams available
                      </div>
                    <% end %>
                  </div>

                  <!-- Current Assignments -->
                  <%= if map_size(@team_assignments) > 0 do %>
                    <div class="mt-4">
                      <label class="block text-sm font-medium text-gray-700 mb-2">Selected Teams (<%= map_size(@team_assignments) %>)</label>
                      <div class="flex flex-wrap gap-2">
                        <%= for {team_id, assignment} <- @team_assignments do %>
                          <div class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-blue-100 text-blue-800">
                            <%= assignment.team_name %>
                            <button
                              type="button"
                              phx-click="remove_team_assignment"
                              phx-value-team-id={team_id}
                              class="ml-2 text-blue-600 hover:text-blue-800"
                            >
                              ×
                            </button>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Hidden inputs to preserve team assignments -->
                <%= for {team_id, _assignment} <- @team_assignments do %>
                  <input type="hidden" name={"team_ids[]"} value={team_id} />
                <% end %>

                <!-- Form Actions -->
                <div class="flex justify-end space-x-3 pt-6 border-t">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Save Changes
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
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

    available_teams = Orgs.list_teams() |> Repo.preload([department: [:organization]])
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
        teams = Orgs.list_teams_by_organization(org_id) |> Repo.preload([department: [:organization]])
        depts = Orgs.list_departments_by_org(org_id)
        {teams, depts}
      else
        teams = Orgs.list_teams() |> Repo.preload([department: [:organization]])
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
        Orgs.list_teams_by_department(dept_id) |> Repo.preload([department: [:organization]])
      else
        if socket.assigns.selected_org_id do
          Orgs.list_teams_by_organization(socket.assigns.selected_org_id) |> Repo.preload([department: [:organization]])
        else
          Orgs.list_teams() |> Repo.preload([department: [:organization]])
        end
      end

    {:noreply,
     socket
     |> assign(:selected_dept_id, dept_id)
     |> assign(:available_teams, available_teams)}
  end

 def handle_event("save_user", params, socket) do
  user = socket.assigns.selected_user

  # Debug: Log what we're receiving
  IO.inspect(params, label: "SAVE USER PARAMS")
  IO.inspect(user, label: "SELECTED USER")
  IO.inspect(socket.assigns.team_assignments, label: "TEAM ASSIGNMENTS")

  # Extract user params (email, username, role, status)
  user_params = %{
    "email" => params["email"],
    "username" => params["username"],
    "role" => params["role"],
    "status" => params["status"]
  }

  IO.inspect(user_params, label: "USER PARAMS FOR UPDATE")

  # Extract team IDs from hidden inputs
  team_ids =
    case params["team_ids"] do
      nil -> []
      ids when is_list(ids) -> Enum.map(ids, &String.to_integer/1)
      id when is_binary(id) -> [String.to_integer(id)]
    end

  IO.inspect(team_ids, label: "TEAM IDs FOR ASSIGNMENT")

  case Accounts.update_user_with_assignments(user, user_params, team_ids) do
    {:ok, updated_user} ->
      IO.inspect(updated_user, label: "SUCCESSFULLY UPDATED USER")
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

  defp user_status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp user_status_class("active"), do: "bg-green-100 text-green-800"
  defp user_status_class(_), do: "bg-gray-100 text-gray-800"

  defp user_status_label("pending"), do: "Pending"
  defp user_status_label("active"), do: "Active"
  defp user_status_label(_), do: "Unknown"

  defp get_current_team_assignments(user) do
    user.employees
    |> Enum.reduce(%{}, fn employee, acc ->
      team_id_str = to_string(employee.team_id)
      Map.put(acc, team_id_str, %{
        team_id: employee.team_id,
        team_name: employee.team.name,
        department_name: employee.department.name,
        organization_name: employee.organization.name
      })
    end)
  end
end
