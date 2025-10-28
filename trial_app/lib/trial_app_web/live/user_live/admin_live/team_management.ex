defmodule TrialAppWeb.AdminLive.TeamManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Repo}

  def mount(_params, _session, socket) do
    teams = Orgs.list_teams() |> Repo.preload([:department, :organization])
    departments = Orgs.list_departments()
    organizations = Orgs.list_organizations()

    {:ok,
     socket
     |> assign(:teams, teams)
     |> assign(:departments, departments)
     |> assign(:organizations, organizations)
     |> assign(:editing_team, nil)
     |> assign(:team_form, %{})
     |> assign(:changeset, nil)}
  end

  def handle_event("new_team", _, socket) do
    {:noreply, assign(socket, :editing_team, :new)}
  end

  def handle_event("edit_team", %{"id" => id}, socket) do
    team = Orgs.get_team_with_preloads!(String.to_integer(id))
    {:noreply, assign(socket, :editing_team, team)}
  end

  def handle_event("delete_team", %{"id" => id}, socket) do
    team = Orgs.get_team!(String.to_integer(id))
    {:ok, _} = Orgs.delete_team(team)

    teams = Orgs.list_teams() |> Repo.preload([:department, :organization])
    {:noreply, assign(socket, :teams, teams)}
  end

  def handle_event("save_team", %{"team" => params}, socket) do
    case socket.assigns.editing_team do
      :new -> create_team(params, socket)
      team -> update_team(team, params, socket)
    end
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_team, nil)}
  end

  defp create_team(params, socket) do
    case Orgs.create_team(params) do
      {:ok, _team} ->
        teams = Orgs.list_teams() |> Repo.preload([:department, :organization])

        {:noreply,
         socket
         |> assign(:teams, teams)
         |> assign(:editing_team, nil)
         |> put_flash(:info, "Team created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp update_team(team, params, socket) do
    case Orgs.update_team(team, params) do
      {:ok, _team} ->
        teams = Orgs.list_teams() |> Repo.preload([:department, :organization])

        {:noreply,
         socket
         |> assign(:teams, teams)
         |> assign(:editing_team, nil)
         |> put_flash(:info, "Team updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Team Management</h1>
        <button
          phx-click="new_team"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          + New Team
        </button>
      </div>

    <!-- Team Form -->
      <%= if @editing_team do %>
        <.team_form
          team={@editing_team}
          departments={@departments}
          organizations={@organizations}
          changeset={@changeset}
        />
      <% end %>

    <!-- Teams List -->
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Department
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                Organization
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for team <- @teams do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {team.name}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {team.department.name}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {team.organization.name}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    phx-click="edit_team"
                    phx-value-id={team.id}
                    class="text-blue-600 hover:text-blue-900 mr-3"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete_team"
                    phx-value-id={team.id}
                    class="text-red-600 hover:text-red-900"
                    onclick="return confirm('Are you sure?')"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp team_form(assigns) do
    ~H"""
    <div class="bg-white p-6 rounded-lg shadow mb-6">
      <h2 class="text-lg font-semibold mb-4">
        {if @team == :new, do: "Create New Team", else: "Edit Team"}
      </h2>

      <form phx-submit="save_team">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Team Name</label>
            <input
              type="text"
              name="team[name]"
              value={if @team != :new, do: @team.name}
              class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
              required
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Department</label>
            <select
              name="team[department_id]"
              class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
            >
              <option value="">Select Department</option>
              <%= for dept <- @departments do %>
                <option
                  value={dept.id}
                  selected={@team != :new && @team.department_id == dept.id}
                >
                  {dept.name}
                </option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Description</label>
            <textarea
              name="team[description]"
              class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
            ><%= if @team != :new && @team.description, do: @team.description %></textarea>
          </div>
        </div>

        <div class="mt-4 flex space-x-2">
          <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
            {if @team == :new, do: "Create Team", else: "Update Team"}
          </button>
          <button
            type="button"
            phx-click="cancel_edit"
            class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
    """
  end
end
