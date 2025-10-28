defmodule TrialAppWeb.OrganizationLive.Index do
  use TrialAppWeb, :live_view
  alias TrialAppWeb.SidebarComponent

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
        socket
        |> assign(:user_status, "pending")
        |> assign(:has_assignments, false)
      }
    else
      # User is active, show organization data
      # Mock data (replace with Organizations.list_organizations/0 later)
      organizations = [
        %{id: 1, name: "Tech Corp", description: "Tech company", email: "info@techcorp.com", phone: "123-456-7890", address: "123 Tech St"},
        %{id: 2, name: "Innovate Ltd", description: "Innovation firm", email: "info@innovate.com", phone: "987-654-3210", address: "456 Innovate Ave"}
      ]

      {:ok,
        socket
        |> assign(:user_status, "active")
        |> assign(:has_assignments, true)
        |> stream(:organizations, organizations)
      }
    end
  end

<<<<<<< Updated upstream
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="flex">
        <.live_component module={SidebarComponent} id="sidebar" socket={@socket} />

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
                    You'll gain access to organization information once your roles are assigned.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What you'll see after approval:</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Organization structure and details</li>
                      <li>• Access to departments and teams</li>
                      <li>• Company-wide information and resources</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Organizations View -->
              <h1 class="text-3xl font-bold text-gray-800 mb-8">Organizations</h1>

              <div class="mb-8 bg-gray-50 p-6 rounded-xl shadow-md">
                <h2 class="text-2xl font-semibold text-gray-700 mb-4">Manage Related</h2>
                <ul class="flex space-x-6">
                  <li>
                    <.link navigate={~p"/departments"} class="text-purple-600 hover:underline font-medium">
                      Departments
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/teams"} class="text-purple-600 hover:underline font-medium">
                      Teams
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/employees"} class="text-purple-600 hover:underline font-medium">
                      Employees
                    </.link>
                  </li>
                  <li>
                    <.link navigate={~p"/positions"} class="text-purple-600 hover:underline font-medium">
                      Positions
                    </.link>
                  </li>
                </ul>
              </div>

              <table class="w-full table-auto border-collapse">
                <thead>
                  <tr class="bg-gray-100">
                    <th class="p-4 text-left">Name</th>
                    <th class="p-4 text-left">Description</th>
                    <th class="p-4 text-left">Email</th>
                    <th class="p-4 text-left">Phone</th>
                    <th class="p-4 text-left">Address</th>
                    <th class="p-4 text-left">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {org_id, org} <- @streams.organizations do %>
                    <tr id={org_id} class="border-b hover:bg-gray-50 transition-colors">
                      <td class="p-4"><%= org.name %></td>
                      <td class="p-4"><%= org.description %></td>
                      <td class="p-4"><%= org.email %></td>
                      <td class="p-4"><%= org.phone %></td>
                      <td class="p-4"><%= org.address %></td>
                      <td class="p-4">
                        <button class="text-purple-600 hover:underline font-medium">Show</button>
                        <button class="text-purple-600 hover:underline ml-2 font-medium">Edit</button>
                        <button class="text-red-600 hover:underline ml-2 font-medium">Delete</button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <div class="mt-6">
                <button class="text-purple-600 hover:underline cursor-pointer font-medium">
                  New Organization
                </button>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
=======
  # Organization CRUD Events
  def handle_event("new_organization", _params, socket) do
    {:noreply, assign(socket,
      show_org_form: true,
      editing_org_id: nil,
      org_form_data: %{name: "", description: ""},
      errors: %{}
    )}
  end

  def handle_event("edit_organization", %{"id" => id}, socket) do
    organization = Organizations.get_organization!(String.to_integer(id))
    {:noreply, assign(socket,
      show_org_form: true,
      editing_org_id: organization.id,
      org_form_data: %{name: organization.name, description: organization.description || ""},
      errors: %{}
    )}
  end

  def handle_event("hide_org_modal", _params, socket) do
    {:noreply, assign(socket,
      show_org_form: false,
      editing_org_id: nil,
      org_form_data: %{name: "", description: ""},
      errors: %{}
    )}
  end

  def handle_event("update_org_form", params, socket) do
    form_data = case params do
      %{"name" => name, "description" => description} ->
        %{name: name, description: description}
      _ ->
        socket.assigns.org_form_data
    end
    {:noreply, assign(socket, org_form_data: form_data)}
  end

  def handle_event("save_organization", params, socket) do
    {name, description} = case params do
      %{"name" => n, "description" => d} -> {n, d}
      _ -> {"", ""}
    end

    errors = if String.trim(name) == "", do: %{name: "Organization name is required"}, else: %{}

    if map_size(errors) == 0 do
      if socket.assigns.editing_org_id do
        organization = Organizations.get_organization!(socket.assigns.editing_org_id)
        case Organizations.update_organization(organization, %{name: name, description: description}) do
          {:ok, updated_org} ->
            updated_organizations = Enum.map(socket.assigns.organizations, fn org ->
              if org.id == updated_org.id, do: updated_org, else: org
            end)
            {:noreply,
              socket
              |> assign(show_org_form: false, editing_org_id: nil, org_form_data: %{name: "", description: ""}, errors: %{})
              |> assign(organizations: updated_organizations)
              |> put_flash(:info, "✅ Organization '#{name}' updated successfully!")
            }
          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Organizations.create_organization(%{name: name, description: description}) do
          {:ok, new_organization} ->
            {:noreply,
              socket
              |> assign(show_org_form: false, org_form_data: %{name: "", description: ""}, errors: %{})
              |> assign(organizations: [new_organization | socket.assigns.organizations])
              |> put_flash(:info, "✅ Organization '#{name}' created successfully!")
            }
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
    {:noreply, assign(socket,
      show_dept_form: true,
      editing_dept_id: nil,
      dept_form_data: %{name: "", description: ""},
      errors: %{}
    )}
  end

  def handle_event("edit_department", %{"id" => id}, socket) do
    department = Organizations.get_department!(String.to_integer(id))
    {:noreply, assign(socket,
      show_dept_form: true,
      editing_dept_id: department.id,
      dept_form_data: %{name: department.name, description: department.description || ""},
      errors: %{}
    )}
  end

  def handle_event("hide_dept_modal", _params, socket) do
    {:noreply, assign(socket,
      show_dept_form: false,
      editing_dept_id: nil,
      dept_form_data: %{name: "", description: ""},
      errors: %{}
    )}
  end

  def handle_event("update_dept_form", params, socket) do
    form_data = case params do
      %{"name" => name, "description" => description} ->
        %{name: name, description: description}
      _ ->
        socket.assigns.dept_form_data
    end
    {:noreply, assign(socket, dept_form_data: form_data)}
  end

  # Team CRUD Events - REMOVED DUPLICATE HANDLERS
  def handle_event("edit_team", %{"id" => team_id}, socket) do
    team = Organizations.get_team!(String.to_integer(team_id))
    {:noreply, assign(socket,
      show_team_form: true,
      editing_team_id: team.id,
      team_form_data: %{name: team.name, description: team.description || "", department_id: team.department_id},
      errors: %{}
    )}
  end

  def handle_event("update_team", %{"team" => team_params}, socket) do
    team = Organizations.get_team!(socket.assigns.editing_team_id)

    case Organizations.update_team(team, team_params) do
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
          |> assign(:team_form_data, %{name: "", description: "", department_id: ""})
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to update team!")
          |> assign(:changeset, changeset)
        }
    end
  end

  def handle_event("delete_team", %{"id" => team_id}, socket) do
    team = Organizations.get_team!(String.to_integer(team_id))

    case Organizations.delete_team(team) do
      {:ok, _} ->
        # Remove from the teams list
        updated_teams =
          socket.assigns.selected_org_teams
          |> Enum.reject(fn t -> t.id == team.id end)

        {:noreply,
          socket
          |> put_flash(:info, "Team deleted successfully!")
          |> assign(:selected_org_teams, updated_teams)
        }

      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to delete team!")
        }
    end
  end

  def handle_event("cancel_edit_team", _params, socket) do
    {:noreply,
      socket
      |> assign(:editing_team_id, nil)
      |> assign(:team_form_data, %{name: "", description: "", department_id: ""})
    }
  end

  def handle_event("save_department", params, socket) do
    {name, description} = case params do
      %{"name" => n, "description" => d} -> {n, d}
      _ -> {"", ""}
    end

    errors = if String.trim(name) == "", do: %{name: "Department name is required"}, else: %{}

    if map_size(errors) == 0 do
      org_id = socket.assigns.selected_org.id
      department_params = %{name: name, description: description, organization_id: org_id}

      if socket.assigns.editing_dept_id do
        department = Organizations.get_department!(socket.assigns.editing_dept_id)
        case Organizations.update_department(department, department_params) do
          {:ok, updated_dept} ->
            updated_departments = Enum.map(socket.assigns.selected_org_departments, fn dept ->
              if dept.id == updated_dept.id, do: updated_dept, else: dept
            end)
            {:noreply,
              socket
              |> assign(show_dept_form: false, editing_dept_id: nil, dept_form_data: %{name: "", description: ""}, errors: %{})
              |> assign(selected_org_departments: updated_departments)
              |> put_flash(:info, "✅ Department '#{name}' updated successfully!")
            }
          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Organizations.create_department(department_params) do
          {:ok, new_department} ->
            {:noreply,
              socket
              |> assign(show_dept_form: false, dept_form_data: %{name: "", description: ""}, errors: %{})
              |> assign(selected_org_departments: [new_department | socket.assigns.selected_org_departments])
              |> put_flash(:info, "✅ Department '#{name}' created successfully!")
            }
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
    {:noreply, assign(socket,
      show_team_form: true,
      editing_team_id: nil,
      team_form_data: %{name: "", description: "", department_id: dept_id},
      errors: %{}
    )}
  end

  def handle_event("hide_team_modal", _params, socket) do
    {:noreply, assign(socket,
      show_team_form: false,
      editing_team_id: nil,
      team_form_data: %{name: "", description: "", department_id: ""},
      errors: %{}
    )}
  end

  def handle_event("update_team_form", params, socket) do
    form_data = case params do
      %{"name" => name, "description" => description, "department_id" => dept_id} ->
        %{name: name, description: description, department_id: dept_id}
      _ ->
        socket.assigns.team_form_data
    end
    {:noreply, assign(socket, team_form_data: form_data)}
  end

  def handle_event("save_team", params, socket) do
    {name, description, department_id} = case params do
      %{"name" => n, "description" => d, "department_id" => dept_id} -> {n, d, dept_id}
      _ -> {"", "", ""}
    end

    errors = %{}
    errors = if String.trim(name) == "", do: Map.put(errors, :name, "Team name is required"), else: errors
    errors = if String.trim(department_id) == "", do: Map.put(errors, :department_id, "Department is required"), else: errors

    if map_size(errors) == 0 do
      team_params = %{name: name, description: description, department_id: String.to_integer(department_id)}

      if socket.assigns.editing_team_id do
        team = Organizations.get_team!(socket.assigns.editing_team_id)
        case Organizations.update_team(team, team_params) do
          {:ok, updated_team} ->
            updated_teams = Enum.map(socket.assigns.selected_org_teams, fn t ->
              if t.id == updated_team.id, do: updated_team, else: t
            end)
            {:noreply,
              socket
              |> assign(show_team_form: false, editing_team_id: nil, team_form_data: %{name: "", description: "", department_id: ""}, errors: %{})
              |> assign(selected_org_teams: updated_teams)
              |> put_flash(:info, "✅ Team '#{name}' updated successfully!")
            }
          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Organizations.create_team(team_params) do
          {:ok, new_team} ->
            {:noreply,
              socket
              |> assign(show_team_form: false, team_form_data: %{name: "", description: "", department_id: ""}, errors: %{})
              |> assign(selected_org_teams: [new_team | socket.assigns.selected_org_teams])
              |> put_flash(:info, "✅ Team '#{name}' created successfully!")
            }
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
    org = Organizations.get_organization!(String.to_integer(id))
    {:noreply,
      socket
      |> assign(:view, :show)
      |> assign(:selected_org, org)
      |> assign(:show_departments, false)
      |> assign(:show_teams, false)
      |> assign(:show_department_detail, false)
      |> assign(:show_team_detail, false)
    }
  end

  def handle_event("back_to_list", _params, socket) do
    {:noreply,
      socket
      |> assign(:view, :list)
      |> assign(:selected_org, nil)
      |> assign(:show_departments, false)
      |> assign(:show_teams, false)
      |> assign(:show_department_detail, false)
      |> assign(:show_team_detail, false)
    }
  end

  def handle_event("show_departments", _params, socket) do
    org_id = socket.assigns.selected_org.id
    departments = Organizations.list_departments(org_id)
    {:noreply,
      socket
      |> assign(:show_departments, true)
      |> assign(:selected_org_departments, departments)
      |> assign(:show_teams, false)
      |> assign(:show_department_detail, false)
      |> assign(:show_team_detail, false)
    }
  end

  def handle_event("show_teams", _params, socket) do
    org_id = socket.assigns.selected_org.id
    teams = Organizations.list_teams_by_organization(org_id)
    {:noreply,
      socket
      |> assign(:show_teams, true)
      |> assign(:selected_org_teams, teams)
      |> assign(:show_departments, false)
      |> assign(:show_department_detail, false)
      |> assign(:show_team_detail, false)
    }
  end

  def handle_event("show_department_detail", %{"id" => id}, socket) do
    department = Organizations.get_department_with_teams!(String.to_integer(id))
    {:noreply,
      socket
      |> assign(:show_department_detail, true)
      |> assign(:selected_department, department)
      |> assign(:show_team_detail, false)
    }
  end

  def handle_event("show_team_detail", %{"id" => id}, socket) do
    team = Organizations.get_team_with_employees!(String.to_integer(id))
    {:noreply,
      socket
      |> assign(:show_team_detail, true)
      |> assign(:selected_team, team)
      |> assign(:show_department_detail, false)
    }
  end

  def handle_event("back_to_departments", _params, socket) do
    {:noreply,
      socket
      |> assign(:show_department_detail, false)
      |> assign(:selected_department, nil)
    }
  end

  def handle_event("back_to_teams", _params, socket) do
    {:noreply,
      socket
      |> assign(:show_team_detail, false)
      |> assign(:selected_team, nil)
    }
  end

  def handle_event("stop", _, socket), do: {:noreply, socket}

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
>>>>>>> Stashed changes
  end
end
