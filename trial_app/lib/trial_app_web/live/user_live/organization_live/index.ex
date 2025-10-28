defmodule TrialAppWeb.OrganizationLive.Index do
  use TrialAppWeb, :live_view
  alias TrialAppWeb.SidebarComponent

  def mount(_params, _session, socket) do
  current_user = socket.assigns.current_scope.user

  if current_user.status == "pending" do
    {:ok,
      socket
      |> assign(:user_status, "pending")
      |> assign(:has_assignments, false)
      # Initialize all expected assigns to prevent KeyError
      |> assign(:view, :list)
      |> assign(:selected_org, nil)
      |> assign(:selected_department, nil)
      |> assign(:selected_team, nil)
      |> assign(:selected_org_departments, [])
      |> assign(:selected_org_teams, [])
      |> assign(:show_departments, false)
      |> assign(:show_teams, false)
      |> assign(:show_department_detail, false)
      |> assign(:show_team_detail, false)
      |> assign(:show_org_form, false)
      |> assign(:show_dept_form, false)
      |> assign(:show_team_form, false)
      |> assign(:editing_org_id, nil)
      |> assign(:editing_dept_id, nil)
      |> assign(:editing_team_id, nil)
      |> assign(:org_form_data, %{name: "", description: ""})
      |> assign(:dept_form_data, %{name: "", description: ""})
      |> assign(:team_form_data, %{name: "", description: "", department_id: ""})
      |> assign(:errors, %{})
    }
  else
    organizations = [
      %{id: 1, name: "Tech Corp", description: "Tech company", email: "info@techcorp.com", phone: "123-456-7890", address: "123 Tech St"},
      %{id: 2, name: "Innovate Ltd", description: "Innovation firm", email: "info@innovate.com", phone: "987-654-3210", address: "456 Innovate Ave"}
    ]

    {:ok,
      socket
      |> assign(:user_status, "active")
      |> assign(:has_assignments, true)
      |> stream(:organizations, organizations)
      # Initialize all expected assigns to prevent KeyError
      |> assign(:view, :list)
      |> assign(:selected_org, nil)
      |> assign(:selected_department, nil)
      |> assign(:selected_team, nil)
      |> assign(:selected_org_departments, [])
      |> assign(:selected_org_teams, [])
      |> assign(:show_departments, false)
      |> assign(:show_teams, false)
      |> assign(:show_department_detail, false)
      |> assign(:show_team_detail, false)
      |> assign(:show_org_form, false)
      |> assign(:show_dept_form, false)
      |> assign(:show_team_form, false)
      |> assign(:editing_org_id, nil)
      |> assign(:editing_dept_id, nil)
      |> assign(:editing_team_id, nil)
      |> assign(:org_form_data, %{name: "", description: ""})
      |> assign(:dept_form_data, %{name: "", description: ""})
      |> assign(:team_form_data, %{name: "", description: "", department_id: ""})
      |> assign(:errors, %{})
    }
  end
end


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
  end
end
