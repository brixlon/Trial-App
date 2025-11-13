defmodule TrialAppWeb.OrganizationLive.Index do
  use TrialAppWeb, :live_view
  alias TrialApp.Orgs
  alias TrialApp.Repo
  import Ecto.Query

  @impl true
@impl true
@impl true
def mount(_params, _session, socket) do
  IO.puts("===== MOUNT CALLED - CODE IS LOADED =====")
  current_user = socket.assigns.current_user

  if current_user.status == "pending" do
    {:ok, socket
     |> assign(:user_status, "pending")
     |> assign(:has_assignments, false)
     |> assign(:current_path, "/organizations")}  # Add this line
  else
    # Load organizations with preloaded departments and teams
    organizations = load_organizations_with_counts()
    IO.inspect(Enum.count(organizations), label: "ORGANIZATIONS COUNT ON MOUNT")

    # Calculate total counts
    total_departments = Repo.aggregate(from(d in TrialApp.Orgs.Department), :count)
    total_teams = Repo.aggregate(from(t in TrialApp.Orgs.Team), :count)

    {:ok,
     socket
     |> assign(:current_path, "/organizations")  # Add this line at the top
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
     |> assign(:show_add_user_modal, false)
     |> assign(:current_team_id, nil)
     |> assign(:available_users, [])
     |> assign(:total_departments, total_departments)
     |> assign(:total_teams, total_teams)
     |> assign(:organizations, organizations)}
  end
end

  # Helper function to load organizations with all necessary counts
  defp load_organizations_with_counts do
    organizations = Repo.all(
      from o in TrialApp.Orgs.Organization,
        left_join: d in assoc(o, :departments),
        left_join: t in assoc(d, :teams),
        preload: [departments: {d, teams: t}],
        order_by: [desc: o.inserted_at]
    )

    IO.inspect(Enum.count(organizations), label: "LOADED ORGANIZATIONS")
    organizations
  end

  # Helper to load a single organization with counts
  defp load_single_organization(org_id) do
    Repo.one!(
      from o in TrialApp.Orgs.Organization,
        where: o.id == ^org_id,
        left_join: d in assoc(o, :departments),
        left_join: t in assoc(d, :teams),
        preload: [departments: {d, teams: t}]
    )
  end

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
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
    IO.puts("=== SAVE ORGANIZATION CALLED ===")
    IO.inspect(params, label: "PARAMS")

    {name, description} =
      case params do
        %{"name" => n, "description" => d} -> {n, d}
        _ -> {"", ""}
      end

    IO.inspect({name, description}, label: "EXTRACTED VALUES")

    errors = %{}
    errors = if String.trim(name) == "", do: Map.put(errors, :name, "Organization name is required"), else: errors

    if map_size(errors) == 0 do
      if socket.assigns.editing_org_id do
        organization = Orgs.get_organization!(socket.assigns.editing_org_id)

        case Orgs.update_organization(organization, %{name: name, description: description}) do
          {:ok, updated_org} ->
            IO.puts("=== ORGANIZATION UPDATED SUCCESSFULLY ===")
            updated_org = load_single_organization(updated_org.id)

            updated_organizations =
              Enum.map(socket.assigns.organizations, fn org ->
                if org.id == updated_org.id, do: updated_org, else: org
              end)

            total_departments = Repo.aggregate(TrialApp.Orgs.Department, :count, :id)
            total_teams = Repo.aggregate(TrialApp.Orgs.Team, :count, :id)

            {:noreply,
             socket
             |> put_flash(:info, "✅ Organization '#{name}' updated successfully!")
             |> assign(
               show_org_form: false,
               editing_org_id: nil,
               org_form_data: %{name: "", description: ""},
               errors: %{},
               organizations: updated_organizations,
               total_departments: total_departments,
               total_teams: total_teams
             )}

          {:error, changeset} ->
            IO.puts("=== ERROR UPDATING ORGANIZATION ===")
            IO.inspect(changeset.errors, label: "CHANGESET ERRORS")
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        org_attrs = %{name: name, description: description, is_active: true}
        IO.inspect(org_attrs, label: "CREATING ORG WITH ATTRS")

        case Orgs.create_organization(org_attrs) do
          {:ok, new_organization} ->
            IO.puts("=== ORGANIZATION CREATED SUCCESSFULLY ===")
            IO.inspect(new_organization, label: "NEW ORG")

            # Reload ALL organizations with proper preloads and counts
            updated_organizations = load_organizations_with_counts()
            IO.inspect(Enum.count(updated_organizations), label: "TOTAL ORGANIZATIONS AFTER CREATE")

            total_departments = Repo.aggregate(TrialApp.Orgs.Department, :count, :id)
            total_teams = Repo.aggregate(TrialApp.Orgs.Team, :count, :id)

            {:noreply,
             socket
             |> put_flash(:info, "✅ Organization '#{name}' created successfully!")
             |> assign(
               show_org_form: false,
               org_form_data: %{name: "", description: ""},
               errors: %{},
               editing_org_id: nil,
               organizations: updated_organizations,
               total_departments: total_departments,
               total_teams: total_teams
             )}

          {:error, changeset} ->
            IO.puts("=== ERROR CREATING ORGANIZATION ===")
            IO.inspect(changeset.errors, label: "CHANGESET ERRORS")
            IO.inspect(changeset, label: "FULL CHANGESET")
            errors = traverse_errors(changeset)
            IO.inspect(errors, label: "TRAVERSED ERRORS")
            {:noreply, assign(socket, errors: errors)}
        end
      end
    else
      IO.puts("=== VALIDATION ERRORS ===")
      IO.inspect(errors, label: "VALIDATION ERRORS")
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
            updated_dept = Repo.preload(updated_dept, :teams, force: true)

            updated_departments =
              Enum.map(socket.assigns.selected_org_departments, fn dept ->
                if dept.id == updated_dept.id, do: updated_dept, else: dept
              end)

            total_departments = Repo.aggregate(from(d in TrialApp.Orgs.Department), :count)

            {:noreply,
             socket
             |> assign(
               show_dept_form: false,
               editing_dept_id: nil,
               dept_form_data: %{name: "", description: ""},
               errors: %{}
             )
             |> assign(selected_org_departments: updated_departments)
             |> assign(total_departments: total_departments)
             |> put_flash(:info, "✅ Department '#{name}' updated successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Orgs.create_department(department_params) do
          {:ok, new_department} ->
            new_department = Repo.preload(new_department, :teams)
            total_departments = Repo.aggregate(from(d in TrialApp.Orgs.Department), :count)

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
             |> assign(total_departments: total_departments)
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

  def handle_event("delete_department", %{"id" => dept_id}, socket) do
    department = Orgs.get_department!(String.to_integer(dept_id))

    case Orgs.delete_department(department) do
      {:ok, _} ->
        updated_departments =
          socket.assigns.selected_org_departments
          |> Enum.reject(fn d -> d.id == department.id end)

        total_departments = Repo.aggregate(from(d in TrialApp.Orgs.Department), :count)
        total_teams = Repo.aggregate(from(t in TrialApp.Orgs.Team), :count)

        {:noreply,
         socket
         |> put_flash(:info, "Department deleted successfully!")
         |> assign(:selected_org_departments, updated_departments)
         |> assign(total_departments: total_departments, total_teams: total_teams)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete department!")}
    end
  end

  # Team CRUD Events
  def handle_event("show_team_selector_modal", _params, socket) do
    org_id = socket.assigns.selected_org.id
    departments =
      Repo.all(
        from d in TrialApp.Orgs.Department,
          where: d.organization_id == ^org_id,
          preload: [:teams]
      )

    {:noreply,
     assign(socket,
       show_team_form: true,
       editing_team_id: nil,
       team_form_data: %{name: "", description: "", department_id: ""},
       selected_org_departments: departments,
       errors: %{}
     )}
  end

  def handle_event("new_team", %{"department_id" => dept_id}, socket) do
    org_id = socket.assigns.selected_org.id
    departments =
      if Enum.empty?(socket.assigns.selected_org_departments) do
        Repo.all(
          from d in TrialApp.Orgs.Department,
            where: d.organization_id == ^org_id,
            preload: [:teams]
        )
      else
        socket.assigns.selected_org_departments
      end

    {:noreply,
     assign(socket,
       show_team_form: true,
       editing_team_id: nil,
       team_form_data: %{name: "", description: "", department_id: dept_id},
       selected_org_departments: departments,
       errors: %{}
     )}
  end

  def handle_event("edit_team", %{"id" => team_id}, socket) do
    team = Orgs.get_team!(String.to_integer(team_id))

    org_id = socket.assigns.selected_org.id
    departments =
      if Enum.empty?(socket.assigns.selected_org_departments) do
        Repo.all(
          from d in TrialApp.Orgs.Department,
            where: d.organization_id == ^org_id,
            preload: [:teams]
        )
      else
        socket.assigns.selected_org_departments
      end

    {:noreply,
     assign(socket,
       show_team_form: true,
       editing_team_id: team.id,
       team_form_data: %{
         name: team.name,
         description: team.description || "",
         department_id: to_string(team.department_id)
       },
       selected_org_departments: departments,
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
      department = Orgs.get_department!(String.to_integer(department_id))

      team_params = %{
        name: name,
        description: description,
        department_id: String.to_integer(department_id),
        organization_id: department.organization_id
      }

      if socket.assigns.editing_team_id do
        team = Orgs.get_team!(socket.assigns.editing_team_id)

        case Orgs.update_team(team, team_params) do
          {:ok, updated_team} ->
            updated_team = Orgs.get_team_with_preloads!(updated_team.id)

            updated_teams =
              if socket.assigns.show_teams do
                org_id = socket.assigns.selected_org.id
                Orgs.list_teams_by_organization(org_id)
              else
                Enum.map(socket.assigns.selected_org_teams, fn t ->
                  if t.id == updated_team.id, do: updated_team, else: t
                end)
              end

            total_teams = Repo.aggregate(from(t in TrialApp.Orgs.Team), :count)

            {:noreply,
             socket
             |> assign(
               show_team_form: false,
               editing_team_id: nil,
               team_form_data: %{name: "", description: "", department_id: ""},
               errors: %{}
             )
             |> assign(selected_org_teams: updated_teams)
             |> assign(total_teams: total_teams)
             |> put_flash(:info, "✅ Team '#{name}' updated successfully!")}

          {:error, changeset} ->
            errors = traverse_errors(changeset)
            {:noreply, assign(socket, errors: errors)}
        end
      else
        case Orgs.create_team(team_params) do
          {:ok, new_team} ->
            new_team = Orgs.get_team_with_preloads!(new_team.id)
            total_teams = Repo.aggregate(from(t in TrialApp.Orgs.Team), :count)

            updated_teams =
              if socket.assigns.show_teams do
                org_id = socket.assigns.selected_org.id
                Orgs.list_teams_by_organization(org_id)
              else
                [new_team | socket.assigns.selected_org_teams]
              end

            {:noreply,
             socket
             |> assign(
               show_team_form: false,
               team_form_data: %{name: "", description: "", department_id: ""},
               errors: %{}
             )
             |> assign(selected_org_teams: updated_teams)
             |> assign(total_teams: total_teams)
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

  def handle_event("confirm_delete_team", %{"id" => team_id}, socket) do
    team = Orgs.get_team!(String.to_integer(team_id))

    case Orgs.delete_team(team) do
      {:ok, _} ->
        updated_teams =
          if socket.assigns.show_teams do
            org_id = socket.assigns.selected_org.id
            Orgs.list_teams_by_organization(org_id)
          else
            socket.assigns.selected_org_teams
            |> Enum.reject(fn t -> t.id == team.id end)
          end

        total_teams = Repo.aggregate(from(t in TrialApp.Orgs.Team), :count)

        {:noreply,
         socket
         |> put_flash(:info, "Team deleted successfully!")
         |> assign(:selected_org_teams, updated_teams)
         |> assign(total_teams: total_teams)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete team!")}
    end
  end

  def handle_event("delete_team", %{"id" => _team_id}, socket) do
    # This just stops propagation, actual deletion happens in confirm_delete_team
    {:noreply, socket}
  end

  # Navigation Events
  def handle_event("show_org", %{"id" => id}, socket) do
    org = load_single_organization(String.to_integer(id))

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
    # If we're in departments or teams view, go back to org detail view
    # Otherwise, go back to the organization list
    if socket.assigns.show_departments or socket.assigns.show_teams do
      {:noreply,
       socket
       |> assign(:show_departments, false)
       |> assign(:show_teams, false)
       |> assign(:show_department_detail, false)
       |> assign(:show_team_detail, false)}
    else
      {:noreply,
       socket
       |> assign(:view, :list)
       |> assign(:selected_org, nil)
       |> assign(:show_departments, false)
       |> assign(:show_teams, false)
       |> assign(:show_department_detail, false)
       |> assign(:show_team_detail, false)}
    end
  end

  def handle_event("show_departments", _params, socket) do
    org_id = socket.assigns.selected_org.id
    departments = Repo.all(
      from d in TrialApp.Orgs.Department,
        where: d.organization_id == ^org_id,
        preload: [:teams],
        order_by: [asc: d.name]
    )

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
    teams = Orgs.list_teams_by_organization(org_id)

    {:noreply,
     socket
     |> assign(:show_teams, true)
     |> assign(:selected_org_teams, teams)
     |> assign(:show_departments, false)
     |> assign(:show_department_detail, false)
     |> assign(:show_team_detail, false)}
  end

  def handle_event("show_department_detail", %{"id" => id}, socket) do
    department =
      Repo.one!(
        from d in TrialApp.Orgs.Department,
          where: d.id == ^String.to_integer(id),
          preload: [teams: :employees]
      )

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

  @impl true
end
