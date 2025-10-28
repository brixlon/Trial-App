defmodule TrialAppWeb.OrganizationLive.Index do
  use TrialAppWeb, :live_view
  # SidebarComponent is referenced directly by module path in templates
  alias TrialApp.Orgs

  # Remove unused alias that triggers warning

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user.status == "pending" do
      {:ok, socket |> assign(:user_status, "pending") |> assign(:has_assignments, false)}
    else
      organizations = Orgs.list_organizations()

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, true)
       |> assign(:view, :list)
       |> assign(:selected_org, nil)
       |> assign(:selected_org_departments, [])
       |> assign(:selected_org_teams, [])
       |> assign(:selected_department, nil)
       |> assign(:selected_team, nil)
       |> assign(:department_employees, [])
       |> assign(:team_employees, [])
       |> assign(:show_departments, false)
       |> assign(:show_teams, false)
       |> assign(:show_department_detail, false)
       |> assign(:show_team_detail, false)
       |> assign(:show_org_form, false)
       |> assign(:show_dept_form, false)
       |> assign(:show_team_form, false)
       |> assign(:org_form_data, %{name: "", description: ""})
       |> assign(:dept_form_data, %{name: "", description: ""})
       |> assign(:team_form_data, %{name: "", description: "", department_id: ""})
       |> assign(:errors, %{})
       |> assign(:editing_org_id, nil)
       |> assign(:editing_dept_id, nil)
       |> assign(:editing_team_id, nil)
       |> assign(:organizations, organizations)}
    end
  end

  # Organization CRUD Events
  @impl true
  def handle_event("new_organization", _params, socket) do
    {:noreply,
     assign(socket,
       show_org_form: true,
       editing_org_id: nil,
       org_form_data: %{name: "", description: ""},
       errors: %{}
     )}
  end

  def handle_event("edit_organization", %{"id" => id}, socket) do
    organization = Orgs.get_organization!(String.to_integer(id))

    {:noreply,
     assign(socket,
       show_org_form: true,
       editing_org_id: organization.id,
       org_form_data: %{name: organization.name, description: organization.description || ""},
       errors: %{}
     )}
  end

  def handle_event("hide_org_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_org_form: false,
       editing_org_id: nil,
       org_form_data: %{name: "", description: ""},
       errors: %{}
     )}
  end

  def handle_event("update_org_form", params, socket) do
    form_data =
      case params do
        %{"name" => name, "description" => description} ->
          %{name: name, description: description}

        _ ->
          socket.assigns.org_form_data
      end

    {:noreply, assign(socket, org_form_data: form_data)}
  end

  def handle_event("save_organization", params, socket) do
    {name, description} =
      case params do
        %{"name" => n, "description" => d} -> {n, d}
        _ -> {"", ""}
      end

    errors = if String.trim(name) == "", do: %{name: "Organization name is required"}, else: %{}

    if map_size(errors) == 0 do
      if socket.assigns.editing_org_id do
        organization = Orgs.get_organization!(socket.assigns.editing_org_id)

        case Orgs.update_organization(organization, %{name: name, description: description}) do
          {:ok, updated_org} ->
            updated_organizations =
              Enum.map(socket.assigns.organizations, fn org ->
                if org.id == updated_org.id, do: updated_org, else: org
              end)

            {:noreply,
             socket
             |> assign(
               show_org_form: false,
               editing_org_id: nil,
               org_form_data: %{name: "", description: ""},
               errors: %{}
             )
             |> assign(organizations: updated_organizations)
             |> put_flash(:info, "✅ Organization '#{name}' updated successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Orgs.create_organization(%{name: name, description: description}) do
          {:ok, new_organization} ->
            {:noreply,
             socket
             |> assign(
               show_org_form: false,
               org_form_data: %{name: "", description: ""},
               errors: %{}
             )
             |> assign(organizations: [new_organization | socket.assigns.organizations])
             |> put_flash(:info, "✅ Organization '#{name}' created successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      end
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  # Department CRUD Events
  def handle_event("new_department", _params, socket) do
    {:noreply,
     assign(socket,
       show_dept_form: true,
       editing_dept_id: nil,
       dept_form_data: %{name: "", description: ""},
       errors: %{}
     )}
  end

  def handle_event("edit_department", %{"id" => id}, socket) do
    department = Orgs.get_department!(String.to_integer(id))

    {:noreply,
     assign(socket,
       show_dept_form: true,
       editing_dept_id: department.id,
       dept_form_data: %{name: department.name, description: department.description || ""},
       errors: %{}
     )}
  end

  def handle_event("hide_dept_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_dept_form: false,
       editing_dept_id: nil,
       dept_form_data: %{name: "", description: ""},
       errors: %{}
     )}
  end

  def handle_event("update_dept_form", params, socket) do
    form_data =
      case params do
        %{"name" => name, "description" => description} ->
          %{name: name, description: description}

        _ ->
          socket.assigns.dept_form_data
      end

    {:noreply, assign(socket, dept_form_data: form_data)}
  end

  # Team CRUD Events - REMOVED DUPLICATE HANDLERS
  def handle_event("edit_team", %{"id" => team_id}, socket) do
    team = Orgs.get_team!(String.to_integer(team_id))

    {:noreply,
     assign(socket,
       show_team_form: true,
       editing_team_id: team.id,
       team_form_data: %{
         name: team.name,
         description: team.description || "",
         department_id: team.department_id
       },
       errors: %{}
     )}
  end

  def handle_event("update_team", %{"team" => team_params}, socket) do
    team = Orgs.get_team!(socket.assigns.editing_team_id)

    case Orgs.update_team(team, team_params) do
      {:ok, updated_team} ->
        # Refresh the teams list
        updated_teams =
          socket.assigns.selected_org_teams
          |> Enum.map(fn t ->
            if t.id == updated_team.id, do: updated_team, else: t
          end)

        {:noreply,
         socket
         |> put_flash(:info, "Team updated successfully!")
         |> assign(:selected_org_teams, updated_teams)
         |> assign(:editing_team_id, nil)
         |> assign(:team_form_data, %{name: "", description: "", department_id: ""})}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update team!")
         |> assign(:changeset, changeset)}
    end
  end

  def handle_event("delete_team", %{"id" => team_id}, socket) do
    team = Orgs.get_team!(String.to_integer(team_id))

    case Orgs.delete_team(team) do
      {:ok, _} ->
        # Remove from the teams list
        updated_teams =
          socket.assigns.selected_org_teams
          |> Enum.reject(fn t -> t.id == team.id end)

        {:noreply,
         socket
         |> put_flash(:info, "Team deleted successfully!")
         |> assign(:selected_org_teams, updated_teams)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete team!")}
    end
  end

  def handle_event("cancel_edit_team", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_team_id, nil)
     |> assign(:team_form_data, %{name: "", description: "", department_id: ""})}
  end

  def handle_event("save_department", params, socket) do
    {name, description} =
      case params do
        %{"name" => n, "description" => d} -> {n, d}
        _ -> {"", ""}
      end

    errors = if String.trim(name) == "", do: %{name: "Department name is required"}, else: %{}

    if map_size(errors) == 0 do
      org_id = socket.assigns.selected_org.id
      department_params = %{name: name, description: description, organization_id: org_id}

      if socket.assigns.editing_dept_id do
        department = Orgs.get_department!(socket.assigns.editing_dept_id)

        case Orgs.update_department(department, department_params) do
          {:ok, updated_dept} ->
            updated_departments =
              Enum.map(socket.assigns.selected_org_departments, fn dept ->
                if dept.id == updated_dept.id, do: updated_dept, else: dept
              end)

            {:noreply,
             socket
             |> assign(
               show_dept_form: false,
               editing_dept_id: nil,
               dept_form_data: %{name: "", description: ""},
               errors: %{}
             )
             |> assign(selected_org_departments: updated_departments)
             |> put_flash(:info, "✅ Department '#{name}' updated successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Orgs.create_department(department_params) do
          {:ok, new_department} ->
            {:noreply,
             socket
             |> assign(
               show_dept_form: false,
               dept_form_data: %{name: "", description: ""},
               errors: %{}
             )
             |> assign(
               selected_org_departments: [
                 new_department | socket.assigns.selected_org_departments
               ]
             )
             |> put_flash(:info, "✅ Department '#{name}' created successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      end
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  # Team CRUD Events
  def handle_event("new_team", %{"department_id" => dept_id}, socket) do
    {:noreply,
     assign(socket,
       show_team_form: true,
       editing_team_id: nil,
       team_form_data: %{name: "", description: "", department_id: dept_id},
       errors: %{}
     )}
  end

  def handle_event("hide_team_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_team_form: false,
       editing_team_id: nil,
       team_form_data: %{name: "", description: "", department_id: ""},
       errors: %{}
     )}
  end

  def handle_event("update_team_form", params, socket) do
    form_data =
      case params do
        %{"name" => name, "description" => description, "department_id" => dept_id} ->
          %{name: name, description: description, department_id: dept_id}

        _ ->
          socket.assigns.team_form_data
      end

    {:noreply, assign(socket, team_form_data: form_data)}
  end

  def handle_event("save_team", params, socket) do
    {name, description, department_id} =
      case params do
        %{"name" => n, "description" => d, "department_id" => dept_id} -> {n, d, dept_id}
        _ -> {"", "", ""}
      end

    errors = %{}

    errors =
      if String.trim(name) == "",
        do: Map.put(errors, :name, "Team name is required"),
        else: errors

    errors =
      if String.trim(department_id) == "",
        do: Map.put(errors, :department_id, "Department is required"),
        else: errors

    if map_size(errors) == 0 do
      team_params = %{
        name: name,
        description: description,
        department_id: String.to_integer(department_id)
      }

      if socket.assigns.editing_team_id do
        team = Orgs.get_team!(socket.assigns.editing_team_id)

        case Orgs.update_team(team, team_params) do
          {:ok, updated_team} ->
            updated_teams =
              Enum.map(socket.assigns.selected_org_teams, fn t ->
                if t.id == updated_team.id, do: updated_team, else: t
              end)

            {:noreply,
             socket
             |> assign(
               show_team_form: false,
               editing_team_id: nil,
               team_form_data: %{name: "", description: "", department_id: ""},
               errors: %{}
             )
             |> assign(selected_org_teams: updated_teams)
             |> put_flash(:info, "✅ Team '#{name}' updated successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Orgs.create_team(team_params) do
          {:ok, new_team} ->
            {:noreply,
             socket
             |> assign(
               show_team_form: false,
               team_form_data: %{name: "", description: "", department_id: ""},
               errors: %{}
             )
             |> assign(selected_org_teams: [new_team | socket.assigns.selected_org_teams])
             |> put_flash(:info, "✅ Team '#{name}' created successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      end
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  # Navigation Events
  def handle_event("show_org", %{"id" => id}, socket) do
    org = Orgs.get_organization!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:view, :show)
     |> assign(:selected_org, org)
     |> assign(:show_departments, false)
     |> assign(:show_teams, false)
     |> assign(:show_department_detail, false)
     |> assign(:show_team_detail, false)}
  end

  def handle_event("back_to_list", _params, socket) do
    {:noreply,
     socket
     |> assign(:view, :list)
     |> assign(:selected_org, nil)
     |> assign(:show_departments, false)
     |> assign(:show_teams, false)
     |> assign(:show_department_detail, false)
     |> assign(:show_team_detail, false)}
  end

  def handle_event("show_departments", _params, socket) do
    org_id = socket.assigns.selected_org.id
    departments = Orgs.list_departments_by_org(org_id)

    {:noreply,
     socket
     |> assign(:show_departments, true)
     |> assign(:selected_org_departments, departments)
     |> assign(:show_teams, false)
     |> assign(:show_department_detail, false)
     |> assign(:show_team_detail, false)}
  end

  def handle_event("show_teams", _params, socket) do
    org_id = socket.assigns.selected_org.id
    teams = Orgs.list_teams_by_dept(org_id)

    {:noreply,
     socket
     |> assign(:show_teams, true)
     |> assign(:selected_org_teams, teams)
     |> assign(:show_departments, false)
     |> assign(:show_department_detail, false)
     |> assign(:show_team_detail, false)}
  end

  def handle_event("show_department_detail", %{"id" => id}, socket) do
    department = Orgs.get_department_with_teams!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:show_department_detail, true)
     |> assign(:selected_department, department)
     |> assign(:show_team_detail, false)}
  end

  def handle_event("show_team_detail", %{"id" => id}, socket) do
    team = Orgs.get_team_with_employees!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:show_team_detail, true)
     |> assign(:selected_team, team)
     |> assign(:show_department_detail, false)}
  end

  def handle_event("back_to_departments", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_department_detail, false)
     |> assign(:selected_department, nil)}
  end

  def handle_event("back_to_teams", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_team_detail, false)
     |> assign(:selected_team, nil)}
  end

  def handle_event("stop", _, socket), do: {:noreply, socket}

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
    <div class="flex h-screen bg-base-200">
      <!-- Sidebar -->
      <.live_component
        module={TrialAppWeb.SidebarComponent}
        id="sidebar"
        current_scope={@current_scope}
        socket={@socket}
      />

    <!-- Main Content -->
      <main class="flex-1 overflow-y-auto ml-64">
        <!-- Header Bar -->
        <div class="bg-white border-b border-purple-100 sticky top-0 z-10">
          <div class="px-8 py-6">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-purple-700 flex items-center gap-3">
                  <span class="text-4xl">🏢</span>
                  <%= cond do %>
                    <% @show_department_detail -> %>
                      Department: {@selected_department && @selected_department.name}
                    <% @show_team_detail -> %>
                      Team: {@selected_team && @selected_team.name}
                    <% @show_departments -> %>
                      Departments in {@selected_org && @selected_org.name}
                    <% @show_teams -> %>
                      Teams in {@selected_org && @selected_org.name}
                    <% @view == :show -> %>
                      {(@selected_org && @selected_org.name) || "Organization"}
                    <% true -> %>
                      Organizations
                  <% end %>
                </h1>
                <p class="text-gray-600 mt-2">
                  <%= cond do %>
                    <% @show_department_detail -> %>
                      Manage teams in this department
                    <% @show_team_detail -> %>
                      Team members and their roles
                    <% @show_departments -> %>
                      Manage departments and their teams
                    <% @show_teams -> %>
                      Manage teams across all departments
                    <% @view == :show -> %>
                      {(@selected_org && @selected_org.description) || ""}
                    <% true -> %>
                      Manage your company organizations and structure
                  <% end %>
                </p>
              </div>
              <div class="flex gap-3">
                <%= if @show_department_detail do %>
                  <button
                    phx-click="back_to_departments"
                    class="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-all font-medium"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M15 19l-7-7 7-7"
                      >
                      </path>
                    </svg>
                    Back to Departments
                  </button>
                <% else %>
                  <%= if @show_team_detail do %>
                    <button
                      phx-click="back_to_teams"
                      class="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-all font-medium"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M15 19l-7-7 7-7"
                        >
                        </path>
                      </svg>
                      Back to Teams
                    </button>
                  <% else %>
                    <%= if @show_departments or @show_teams do %>
                      <button
                        phx-click="back_to_list"
                        class="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-all font-medium"
                      >
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M15 19l-7-7 7-7"
                          >
                          </path>
                        </svg>
                        Back to Organization
                      </button>
                    <% else %>
                      <%= if @view == :show do %>
                        <button
                          phx-click="back_to_list"
                          class="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-all font-medium"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M15 19l-7-7 7-7"
                            >
                            </path>
                          </svg>
                          Back to Organizations
                        </button>
                      <% end %>
                    <% end %>
                  <% end %>
                <% end %>

    <!-- Add buttons for current context -->
                <%= if @show_departments and @current_scope.user.role == "admin" do %>
                  <button
                    phx-click="new_department"
                    class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-xl hover:from-green-700 hover:to-green-800 transition-all shadow-lg hover:shadow-xl font-semibold"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 4v16m8-8H4"
                      />
                    </svg>
                    Add Department
                  </button>
                <% else %>
                  <%= if @show_department_detail and @current_scope.user.role == "admin" do %>
                    <button
                      phx-click="new_team"
                      phx-value-department_id={@selected_department.id}
                      class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl hover:from-blue-700 hover:to-blue-800 transition-all shadow-lg hover:shadow-xl font-semibold"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 4v16m8-8H4"
                        />
                      </svg>
                      Add Team
                    </button>
                  <% else %>
                    <%= if @view == :list and @current_scope.user.role == "admin" do %>
                      <button
                        phx-click="new_organization"
                        class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl font-semibold"
                      >
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M12 4v16m8-8H4"
                          />
                        </svg>
                        Add Organization
                      </button>
                    <% end %>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>

    <!-- Content Area -->
        <div class="p-8">
          <div class="max-w-7xl mx-auto">
            <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="bg-white rounded-2xl shadow-sm p-16 text-center">
                <div class="max-w-md mx-auto">
                  <div class="text-7xl mb-6">⏳</div>
                  <h3 class="text-2xl font-bold text-gray-900 mb-2">Access Restricted</h3>
                  <p class="text-gray-600 mb-8">
                    Your account is pending administrator approval.
                    You'll gain access to organization information once your account is activated.
                  </p>
                </div>
              </div>
            <% else %>
              <!-- Organizations List View -->
              <%= if @view == :list do %>
                <!-- Stats Cards -->
                <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                  <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 text-white shadow-lg">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-blue-100 text-sm font-semibold">Total Organizations</p>
                        <p class="text-4xl font-bold mt-2">{Enum.count(@organizations)}</p>
                      </div>
                      <div class="text-5xl opacity-50">🏢</div>
                    </div>
                  </div>

                  <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white shadow-lg">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-green-100 text-sm font-semibold">Active</p>
                        <p class="text-4xl font-bold mt-2">{Enum.count(@organizations)}</p>
                      </div>
                      <div class="text-5xl opacity-50">✅</div>
                    </div>
                  </div>

                  <div class="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-6 text-white shadow-lg">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-purple-100 text-sm font-semibold">Departments</p>
                        <p class="text-4xl font-bold mt-2">0</p>
                      </div>
                      <div class="text-5xl opacity-50">🏛️</div>
                    </div>
                  </div>

                  <div class="bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl p-6 text-white shadow-lg">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-orange-100 text-sm font-semibold">Teams</p>
                        <p class="text-4xl font-bold mt-2">0</p>
                      </div>
                      <div class="text-5xl opacity-50">👥</div>
                    </div>
                  </div>
                </div>

    <!-- Organizations Grid/List -->
                <%= if Enum.empty?(@organizations) do %>
                  <!-- Empty State -->
                  <div class="bg-white rounded-2xl shadow-sm p-16 text-center">
                    <div class="max-w-md mx-auto">
                      <div class="text-7xl mb-6">🏢</div>
                      <h3 class="text-2xl font-bold text-gray-900 mb-2">No Organizations Yet</h3>
                      <p class="text-gray-600 mb-8">
                        Get started by creating your first organization to structure your company.
                      </p>
                      <%= if @current_scope.user.role == "admin" do %>
                        <button
                          phx-click="new_organization"
                          class="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg font-semibold"
                        >
                          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M12 4v16m8-8H4"
                            />
                          </svg>
                          Create First Organization
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% else %>
                  <!-- Organizations Grid -->
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    <%= for org <- @organizations do %>
                      <div class="bg-white rounded-xl shadow-sm hover:shadow-lg transition-all border-2 border-gray-100 hover:border-indigo-200 p-6 group">
                        <div class="flex items-start justify-between mb-4">
                          <div class="flex items-center gap-3">
                            <div class="w-12 h-12 bg-gradient-to-br from-indigo-500 to-purple-500 rounded-xl flex items-center justify-center text-2xl">
                              🏢
                            </div>
                            <div>
                              <h3 class="font-bold text-lg text-gray-900 group-hover:text-indigo-600 transition-colors">
                                {org.name}
                              </h3>
                              <span class="text-sm text-gray-500">Active</span>
                            </div>
                          </div>
                          <div class="flex gap-1">
                            <%= if @current_scope.user.role == "admin" do %>
                              <button
                                phx-click="edit_organization"
                                phx-value-id={org.id}
                                class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                                title="Edit Organization"
                              >
                                <svg
                                  class="w-4 h-4"
                                  fill="none"
                                  stroke="currentColor"
                                  viewBox="0 0 24 24"
                                >
                                  <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    stroke-width="2"
                                    d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                                  />
                                </svg>
                              </button>
                            <% end %>
                          </div>
                        </div>

                        <p class="text-gray-600 text-sm mb-4 line-clamp-2">
                          <%= if org.description && org.description != "" do %>
                            {org.description}
                          <% else %>
                            <span class="text-gray-400 italic">No description provided</span>
                          <% end %>
                        </p>

                        <div class="flex items-center gap-4 text-sm text-gray-500 pt-4 border-t border-gray-100">
                          <div class="flex items-center gap-1">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                              />
                            </svg>
                            <span>0 Departments</span>
                          </div>
                          <div class="flex items-center gap-1">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                              />
                            </svg>
                            <span>0 Teams</span>
                          </div>
                        </div>

                        <button
                          phx-click="show_org"
                          phx-value-id={org.id}
                          class="w-full mt-4 py-2 bg-gray-100 hover:bg-indigo-600 hover:text-white text-gray-700 rounded-lg transition-all font-medium"
                        >
                          View Details
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>

    <!-- Organization Detail View -->
              <% else %>
                <%= if @show_department_detail do %>
                  <!-- Department Teams View -->
                  <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                    <div class="flex items-center justify-between mb-6">
                      <h2 class="text-2xl font-bold text-gray-900 flex items-center gap-3">
                        <span class="text-3xl">👥</span> Teams in {@selected_department.name}
                      </h2>
                      <%= if @current_scope.user.role == "admin" do %>
                        <button
                          phx-click="edit_department"
                          phx-value-id={@selected_department.id}
                          class="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-all font-medium"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                            />
                          </svg>
                          Edit Department
                        </button>
                      <% end %>
                    </div>

                    <%= if Enum.empty?(@selected_department.teams) do %>
                      <!-- Empty Teams State -->
                      <div class="text-center py-12 border-2 border-dashed border-gray-300 rounded-xl">
                        <div class="text-6xl mb-4">👥</div>
                        <h3 class="text-xl font-semibold text-gray-700 mb-2">No Teams Yet</h3>
                        <p class="text-gray-500 mb-6">Create your first team in this department.</p>
                        <%= if @current_scope.user.role == "admin" do %>
                          <button
                            phx-click="new_team"
                            phx-value-department_id={@selected_department.id}
                            class="inline-flex items-center gap-2 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-all font-medium"
                          >
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M12 4v16m8-8H4"
                              />
                            </svg>
                            Create First Team
                          </button>
                        <% end %>
                      </div>
                    <% else %>
                      <!-- Teams Grid -->
                      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        <%= for team <- @selected_department.teams do %>
                          <div
                            class="bg-blue-50 rounded-lg p-4 border border-blue-200 hover:shadow-md transition-all cursor-pointer group relative"
                            phx-click="show_team_detail"
                            phx-value-id={team.id}
                          >
                            <div class="flex items-start justify-between mb-3">
                              <h3 class="font-semibold text-blue-800 text-lg">{team.name}</h3>
                              <%= if @current_scope.user.role == "admin" do %>
                                <div class="flex space-x-1" phx-click="stop">
                                  <button
                                    phx-click="edit_team"
                                    phx-value-id={team.id}
                                    class="p-1 text-blue-400 hover:text-blue-600 hover:bg-blue-100 rounded transition-colors"
                                    title="Edit team"
                                  >
                                    <svg
                                      class="w-4 h-4"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        stroke-linecap="round"
                                        stroke-linejoin="round"
                                        stroke-width="2"
                                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                                      />
                                    </svg>
                                  </button>
                                  <button
                                    phx-click="delete_team"
                                    phx-value-id={team.id}
                                    class="p-1 text-red-400 hover:text-red-600 hover:bg-red-100 rounded transition-colors"
                                    onclick="return confirm('Are you sure you want to delete #{team.name} team?')"
                                    title="Delete team"
                                  >
                                    <svg
                                      class="w-4 h-4"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        stroke-linecap="round"
                                        stroke-linejoin="round"
                                        stroke-width="2"
                                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                                      />
                                    </svg>
                                  </button>
                                </div>
                              <% end %>
                            </div>
                            <p class="text-blue-600 text-sm mb-3">
                              <%= if team.description && team.description != "" do %>
                                {team.description}
                              <% else %>
                                <span class="italic text-blue-500">No description</span>
                              <% end %>
                            </p>
                            <div class="flex items-center justify-between text-xs text-blue-500">
                              <span>
                                <%= case team.employees do %>
                                  <% %Ecto.Association.NotLoaded{} -> %>
                                    Loading...
                                  <% employees when is_list(employees) -> %>
                                    {Enum.count(employees)} members
                                <% end %>
                              </span>
                              <span class="group-hover:text-blue-700">View team →</span>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <%= if @show_team_detail do %>
                    <!-- Team Employees View -->
                    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                      <div class="flex items-center justify-between mb-6">
                        <h2 class="text-2xl font-bold text-gray-900 flex items-center gap-3">
                          <span class="text-3xl">👤</span> Team Members in {@selected_team.name}
                        </h2>
                        <div class="flex gap-2">
                          <%= if @current_scope.user.role == "admin" do %>
                            <button
                              phx-click="edit_team"
                              phx-value-id={@selected_team.id}
                              class="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-all font-medium"
                            >
                              <svg
                                class="w-4 h-4"
                                fill="none"
                                stroke="currentColor"
                                viewBox="0 0 24 24"
                              >
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  stroke-width="2"
                                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                                />
                              </svg>
                              Edit Team
                            </button>
                          <% end %>
                        </div>
                      </div>

                      <p class="text-gray-600 mb-6">
                        Department:
                        <span class="font-semibold">{@selected_team.department.name}</span>
                        <%= if @selected_team.description && @selected_team.description != "" do %>
                          • {@selected_team.description}
                        <% end %>
                      </p>

                      <%= if Enum.empty?(@selected_team.employees) do %>
                        <div class="text-center py-12 border-2 border-dashed border-gray-300 rounded-xl">
                          <div class="text-6xl mb-4">👤</div>
                          <h3 class="text-xl font-semibold text-gray-700 mb-2">No Team Members</h3>
                          <p class="text-gray-500">This team doesn't have any members yet.</p>
                        </div>
                      <% else %>
                        <!-- Employees Table -->
                        <div class="overflow-x-auto">
                          <table class="min-w-full divide-y divide-gray-200">
                            <thead class="bg-gray-50">
                              <tr>
                                <th
                                  scope="col"
                                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                                >
                                  Name
                                </th>
                                <th
                                  scope="col"
                                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                                >
                                  Position
                                </th>
                                <th
                                  scope="col"
                                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                                >
                                  Email
                                </th>
                                <th
                                  scope="col"
                                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                                >
                                  Role
                                </th>
                                <th
                                  scope="col"
                                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                                >
                                  Status
                                </th>
                              </tr>
                            </thead>
                            <tbody class="bg-white divide-y divide-gray-200">
                              <%= for employee <- @selected_team.employees do %>
                                <tr class="hover:bg-gray-50 transition-colors">
                                  <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="text-sm font-medium text-gray-900">
                                      {employee.name}
                                    </div>
                                  </td>
                                  <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="text-sm text-gray-900">
                                      {employee.position || "Not assigned"}
                                    </div>
                                  </td>
                                  <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="text-sm text-gray-900">
                                      {employee.email}
                                    </div>
                                  </td>
                                  <td class="px-6 py-4 whitespace-nowrap">
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                      {employee.role || "Not assigned"}
                                    </span>
                                  </td>
                                  <td class="px-6 py-4 whitespace-nowrap">
                                    <%= if employee.position do %>
                                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                        Active
                                      </span>
                                    <% else %>
                                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                        Inactive
                                      </span>
                                    <% end %>
                                  </td>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <%= if @show_departments do %>
                      <!-- Departments List View -->
                      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
                        <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-3">
                          <span class="text-3xl">🏛️</span> Departments in {@selected_org.name}
                        </h2>
                        <%= if Enum.empty?(@selected_org_departments) do %>
                          <!-- Empty Departments State -->
                          <div class="text-center py-12 border-2 border-dashed border-gray-300 rounded-xl">
                            <div class="text-6xl mb-4">🏛️</div>
                            <h3 class="text-xl font-semibold text-gray-700 mb-2">
                              No Departments Yet
                            </h3>
                            <p class="text-gray-500 mb-6">
                              Create your first department in this organization.
                            </p>
                            <%= if @current_scope.user.role == "admin" do %>
                              <button
                                phx-click="new_department"
                                class="inline-flex items-center gap-2 px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-all font-medium"
                              >
                                <svg
                                  class="w-5 h-5"
                                  fill="none"
                                  stroke="currentColor"
                                  viewBox="0 0 24 24"
                                >
                                  <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    stroke-width="2"
                                    d="M12 4v16m8-8H4"
                                  />
                                </svg>
                                Create First Department
                              </button>
                            <% end %>
                          </div>
                        <% else %>
                          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                            <%= for dept <- @selected_org_departments do %>
                              <div
                                class="bg-purple-50 rounded-lg p-4 border border-purple-200 hover:shadow-md transition-all cursor-pointer group"
                                phx-click="show_department_detail"
                                phx-value-id={dept.id}
                              >
                                <div class="flex items-start justify-between mb-3">
                                  <h3 class="font-semibold text-purple-800 text-lg">{dept.name}</h3>
                                  <%= if @current_scope.user.role == "admin" do %>
                                    <button
                                      phx-click="edit_department"
                                      phx-value-id={dept.id}
                                      class="p-1 text-purple-400 hover:text-purple-600 hover:bg-purple-100 rounded transition-colors"
                                      onclick="event.stopPropagation();"
                                    >
                                      <svg
                                        class="w-4 h-4"
                                        fill="none"
                                        stroke="currentColor"
                                        viewBox="0 0 24 24"
                                      >
                                        <path
                                          stroke-linecap="round"
                                          stroke-linejoin="round"
                                          stroke-width="2"
                                          d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                                        />
                                      </svg>
                                    </button>
                                  <% end %>
                                </div>
                                <p class="text-purple-600 text-sm mb-3">
                                  {dept.name}
                                </p>
                                <div class="flex items-center justify-between text-xs text-purple-500">
                                  <span>0 teams</span>
                                  <span class="group-hover:text-purple-700">View department →</span>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <%= if @show_teams do %>
                        <!-- Teams List View -->
                        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                          <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-3">
                            <span class="text-3xl">👥</span> Teams in {@selected_org.name}
                          </h2>
                          <%= if Enum.empty?(@selected_org_teams) do %>
                            <div class="text-center py-8">
                              <div class="text-5xl mb-4">👥</div>
                              <p class="text-gray-600 text-lg">
                                No teams found for this organization.
                              </p>
                            </div>
                          <% else %>
                            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                              <%= for team <- @selected_org_teams do %>
                                <div
                                  class="bg-blue-50 rounded-lg p-4 border border-blue-200 hover:shadow-md transition-all cursor-pointer group relative"
                                  phx-click="show_team_detail"
                                  phx-value-id={team.id}
                                >

    <!-- Action Buttons - Top Right -->
                                  <div
                                    class="absolute top-2 right-2 flex space-x-1 opacity-0 group-hover:opacity-100 transition-opacity"
                                    phx-click="stop"
                                  >
                                    <!-- Edit Button -->
                                    <button
                                      phx-click="edit_team"
                                      phx-value-id={team.id}
                                      class="p-1 bg-white rounded-full shadow-sm hover:bg-blue-50 border border-blue-200"
                                      title="Edit team"
                                    >
                                      <svg
                                        class="w-3 h-3 text-blue-600"
                                        fill="none"
                                        stroke="currentColor"
                                        viewBox="0 0 24 24"
                                      >
                                        <path
                                          stroke-linecap="round"
                                          stroke-linejoin="round"
                                          stroke-width="2"
                                          d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                                        />
                                      </svg>
                                    </button>

    <!-- Delete Button -->
                                    <button
                                      phx-click="delete_team"
                                      phx-value-id={team.id}
                                      class="p-1 bg-white rounded-full shadow-sm hover:bg-red-50 border border-red-200"
                                      onclick="return confirm('Are you sure you want to delete #{team.name} team?')"
                                      title="Delete team"
                                    >
                                      <svg
                                        class="w-3 h-3 text-red-600"
                                        fill="none"
                                        stroke="currentColor"
                                        viewBox="0 0 24 24"
                                      >
                                        <path
                                          stroke-linecap="round"
                                          stroke-linejoin="round"
                                          stroke-width="2"
                                          d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                                        />
                                      </svg>
                                    </button>
                                  </div>

    <!-- Team Content -->
                                  <h3 class="font-semibold text-blue-800 mb-2 pr-8">{team.name}</h3>
                                  <p class="text-blue-600 text-sm mb-2">
                                    <%= if team.description && team.description != "" do %>
                                      {team.description}
                                    <% else %>
                                      <span class="italic">No description</span>
                                    <% end %>
                                  </p>
                                  <p class="text-blue-500 text-xs">
                                    Department: {team.department.name}
                                  </p>
                                  <p class="text-blue-400 text-xs mt-1">
                                    <strong>Click to view team members</strong>
                                  </p>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      <% else %>
                        <!-- Organization Actions -->
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                          <button
                            phx-click="show_departments"
                            class="p-8 bg-gradient-to-br from-purple-500 to-purple-600 text-white rounded-xl border-2 border-purple-200 transition-all shadow-lg hover:shadow-xl hover:scale-105"
                          >
                            <div class="text-2xl font-bold mb-2">🏛️ Departments</div>
                            <div class="text-purple-100">View and manage departments</div>
                          </button>

                          <button
                            phx-click="show_teams"
                            class="p-8 bg-gradient-to-br from-blue-500 to-blue-600 text-white rounded-xl border-2 border-blue-200 transition-all shadow-lg hover:shadow-xl hover:scale-105"
                          >
                            <div class="text-2xl font-bold mb-2">👥 Teams</div>
                            <div class="text-blue-100">View all teams across departments</div>
                          </button>
                        </div>
                      <% end %>
                    <% end %>
                  <% end %>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </div>
      </main>

    <!-- Organization Modal -->
      <%= if @show_org_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl transform transition-all">
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-500 rounded-xl flex items-center justify-center text-xl">
                  🏢
                </div>
                <h2 class="text-2xl font-bold text-gray-900">
                  {if @editing_org_id, do: "Edit Organization", else: "Add New Organization"}
                </h2>
              </div>
              <button
                phx-click="hide_org_modal"
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <form phx-submit="save_organization" phx-change="update_org_form" class="p-6 space-y-6">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Organization Name *
                </label>
                <input
                  type="text"
                  name="name"
                  value={@org_form_data.name}
                  placeholder="e.g., Tech Company Inc, Marketing Agency"
                  class={[
                    "w-full px-4 py-3 border-2 rounded-xl outline-none transition-all",
                    if(@errors[:name],
                      do: "border-red-300 bg-red-50 focus:ring-2 focus:ring-red-500",
                      else:
                        "border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    )
                  ]}
                  required
                />
                <%= if @errors[:name] do %>
                  <p class="mt-2 text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path
                        fill-rule="evenodd"
                        d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    {@errors[:name]}
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Description</label>
                <textarea
                  name="description"
                  rows="4"
                  placeholder="Brief description of this organization's purpose and activities..."
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all resize-none"
                ><%= @org_form_data.description %></textarea>
              </div>

              <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="hide_org_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg font-semibold"
                >
                  {if @editing_org_id, do: "Update Organization", else: "Create Organization"}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

    <!-- Department Modal -->
      <%= if @show_dept_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl transform transition-all">
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-green-500 to-green-600 rounded-xl flex items-center justify-center text-xl">
                  🏛️
                </div>
                <h2 class="text-2xl font-bold text-gray-900">
                  {if @editing_dept_id, do: "Edit Department", else: "Add New Department"}
                </h2>
              </div>
              <button
                phx-click="hide_dept_modal"
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <form phx-submit="save_department" phx-change="update_dept_form" class="p-6 space-y-6">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Department Name *
                </label>
                <input
                  type="text"
                  name="name"
                  value={@dept_form_data.name}
                  placeholder="e.g., Engineering, Sales, HR"
                  class={[
                    "w-full px-4 py-3 border-2 rounded-xl outline-none transition-all",
                    if(@errors[:name],
                      do: "border-red-300 bg-red-50 focus:ring-2 focus:ring-red-500",
                      else: "border-gray-300 focus:ring-2 focus:ring-green-500 focus:border-green-500"
                    )
                  ]}
                  required
                />
                <%= if @errors[:name] do %>
                  <p class="mt-2 text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path
                        fill-rule="evenodd"
                        d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    {@errors[:name]}
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Description</label>
                <textarea
                  name="description"
                  rows="4"
                  placeholder="Brief description of this department's role and responsibilities..."
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-green-500 focus:border-green-500 outline-none transition-all resize-none"
                ><%= @dept_form_data.description %></textarea>
              </div>

              <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="hide_dept_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-3 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-xl hover:from-green-700 hover:to-green-800 transition-all shadow-lg font-semibold"
                >
                  {if @editing_dept_id, do: "Update Department", else: "Create Department"}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

    <!-- Team Modal -->
      <%= if @show_team_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl transform transition-all">
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl flex items-center justify-center text-xl">
                  👥
                </div>
                <h2 class="text-2xl font-bold text-gray-900">
                  {if @editing_team_id, do: "Edit Team", else: "Add New Team"}
                </h2>
              </div>
              <button
                phx-click="hide_team_modal"
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <form phx-submit="save_team" phx-change="update_team_form" class="p-6 space-y-6">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Team Name *</label>
                <input
                  type="text"
                  name="name"
                  value={@team_form_data.name}
                  placeholder="e.g., Frontend Team, Sales Team, DevOps"
                  class={[
                    "w-full px-4 py-3 border-2 rounded-xl outline-none transition-all",
                    if(@errors[:name],
                      do: "border-red-300 bg-red-50 focus:ring-2 focus:ring-red-500",
                      else: "border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    )
                  ]}
                  required
                />
                <%= if @errors[:name] do %>
                  <p class="mt-2 text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path
                        fill-rule="evenodd"
                        d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    {@errors[:name]}
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Description</label>
                <textarea
                  name="description"
                  rows="3"
                  placeholder="Brief description of this team's purpose and focus..."
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all resize-none"
                ><%= @team_form_data.description %></textarea>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Department *</label>
                <select
                  name="department_id"
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                  required
                >
                  <option value="">Select a department</option>
                  <%= for dept <- @selected_org_departments do %>
                    <option
                      value={dept.id}
                      selected={dept.id == String.to_integer(@team_form_data.department_id)}
                    >
                      {dept.name}
                    </option>
                  <% end %>
                </select>
                <%= if @errors[:department_id] do %>
                  <p class="mt-2 text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path
                        fill-rule="evenodd"
                        d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    {@errors[:department_id]}
                  </p>
                <% end %>
              </div>

              <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="hide_team_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-3 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl hover:from-blue-700 hover:to-blue-800 transition-all shadow-lg font-semibold"
                >
                  {if @editing_team_id, do: "Update Team", else: "Create Team"}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
 