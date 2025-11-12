defmodule TrialAppWeb.AdminLive.ProjectManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}
  alias TrialApp.Accounts

  # ──────────────────────────────────────────────────────────────────────
  # MOUNT
  # ──────────────────────────────────────────────────────────────────────
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:projects, list_projects_with_preloads())
     |> assign(:filter_status, "all")
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_project, nil)
     |> assign(:viewing_project, nil)
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:supervisors, Accounts.list_users_by_role("admin") ++ Accounts.list_users_by_role("manager"))
     |> assign(:form, to_form(empty_form(), as: :project))
     |> assign(:errors, %{})}
  end

  # ──────────────────────────────────────────────────────────────────────
  # EVENTS
  # ──────────────────────────────────────────────────────────────────────

  # Filter by status
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  # Open new form
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_project, nil)
     |> assign(:form, to_form(empty_form(), as: :project))
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:errors, %{})}
  end

  # Close all modals
  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_project, nil)
     |> assign(:viewing_project, nil)
     |> assign(:form, to_form(empty_form(), as: :project))
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:errors, %{})}
  end

  # Stop modal close when clicking inside
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  # Live validation
  def handle_event("validate", %{"project" => params}, socket) do
    changeset =
      %Eams.Project{}
      |> Eams.Project.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :project))}
  end

  # Dynamic dropdowns (org → dept → program)
  def handle_event("update", %{"project" => params}, socket) do
    org_id = safe_int(params["organization_id"])
    dept_id = safe_int(params["department_id"])

    departments = if org_id, do: Orgs.list_departments_by_org(org_id), else: []
    programs = if dept_id, do: Eams.list_programs_by_department(dept_id), else: []

    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :project))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  # Save (create or update)
  def handle_event("save", %{"project" => params}, socket) do
    require Logger
    Logger.info("Saving project: #{inspect(params)}")

    case validate_dates(params) do
      {:ok, _} ->
        attrs = %{
          name: params["name"],
          description: params["description"],
          code: params["code"],
          starts_on: parse_date(params["starts_on"]),
          ends_on: parse_date(params["ends_on"]),
          organization_id: parse_int(params["organization_id"]),
          department_id: parse_int(params["department_id"]),
          program_id: parse_int(params["program_id"]),
          supervisor_id: parse_int(params["supervisor_id"]),
          is_active: true
        }

        result =
          if socket.assigns.editing_project do
            Eams.update_project(socket.assigns.editing_project, attrs)
          else
            Eams.create_project(attrs)
          end

        case result do
          {:ok, _project} ->
            {:noreply,
             socket
             |> assign(:show_form, false)
             |> assign(:editing_project, nil)
             |> assign(:form, to_form(empty_form(), as: :project))
             |> assign(:departments, [])
             |> assign(:programs, [])
             |> assign(:projects, list_projects_with_preloads())
             |> assign(:errors, %{})
             |> put_flash(:info, "Project #{if socket.assigns.editing_project, do: "updated", else: "created"} successfully")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset, as: :project))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to save project: #{inspect(reason)}")}
        end

      {:error, message} ->
        changeset =
          %Eams.Project{}
          |> Eams.Project.changeset(params)
          |> Ecto.Changeset.add_error(:date_range, message)
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, :form, to_form(changeset, as: :project))}
    end
  end

  # View project
  def handle_event("view_project", %{"id" => id}, socket) do
    project =
      Eams.get_project!(parse_int(id))
      |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor])

    {:noreply,
     socket
     |> assign(:viewing_project, project)
     |> assign(:show_view_modal, true)}
  end

  # Edit project
  def handle_event("edit_project", %{"id" => id}, socket) do
    project =
      Eams.get_project!(parse_int(id))
      |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor])

    org_id = project.organization_id
    dept_id = project.department_id

    departments = if org_id, do: Orgs.list_departments_by_org(org_id), else: []
    programs = if dept_id, do: Eams.list_programs_by_department(dept_id), else: []

    form_data = %{
      "name" => project.name || "",
      "description" => project.description || "",
      "code" => project.code || "",
      "starts_on" => if(project.starts_on, do: Date.to_string(project.starts_on), else: ""),
      "ends_on" => if(project.ends_on, do: Date.to_string(project.ends_on), else: ""),
      "organization_id" => if(org_id, do: to_string(org_id), else: ""),
      "department_id" => if(dept_id, do: to_string(dept_id), else: ""),
      "program_id" => if(project.program_id, do: to_string(project.program_id), else: ""),
      "supervisor_id" => if(project.supervisor_id, do: to_string(project.supervisor_id), else: "")
    }

    {:noreply,
     socket
     |> assign(:editing_project, project)
     |> assign(:show_form, true)
     |> assign(:form, to_form(form_data, as: :project))
     |> assign(:departments, departments)
     |> assign(:programs, programs)
     |> assign(:errors, %{})}
  end

  # Delete project
  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Eams.get_project!(parse_int(id))

    case Eams.delete_project(project) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> assign(:projects, list_projects_with_preloads())
         |> put_flash(:info, "Project deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to delete project")}
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # HELPERS
  # ──────────────────────────────────────────────────────────────────────

  defp list_projects_with_preloads do
    Eams.list_projects()
    |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor])
  end

  defp empty_form do
    %{
      "name" => "",
      "description" => "",
      "organization_id" => "",
      "department_id" => "",
      "program_id" => "",
      "supervisor_id" => "",
      "code" => "",
      "starts_on" => "",
      "ends_on" => ""
    }
  end

  defp filtered_projects(projects, "all"), do: projects
  defp filtered_projects(projects, status) do
    case status do
      "active" -> Enum.filter(projects, & &1.is_active)
      "inactive" -> Enum.filter(projects, & !&1.is_active)
      "completed" -> Enum.filter(projects, &(&1.ends_on && Date.compare(&1.ends_on, Date.utc_today()) == :lt))
      _ -> projects
    end
  end

  defp count_by_status(projects, "all"), do: length(projects)
  defp count_by_status(projects, "active"), do: Enum.count(projects, & &1.is_active)
  defp count_by_status(projects, "inactive"), do: Enum.count(projects, & !&1.is_active)
  defp count_by_status(projects, "completed"), do: Enum.count(projects, &(&1.ends_on && Date.compare(&1.ends_on, Date.utc_today()) == :lt))

  defp get_assoc_name(nil), do: "—"
  defp get_assoc_name(struct), do: struct.name

  defp get_supervisor_name(nil), do: "Unassigned"
  defp get_supervisor_name(user), do: user.username || user.email

  defp format_date(nil), do: "Not set"
  defp format_date(date), do: Calendar.strftime(date, "%b %d, %Y")

  defp status_color(project) do
    cond do
      !project.is_active -> "bg-gray-100 text-gray-800"
      project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt -> "bg-blue-100 text-blue-800"
      project.starts_on && Date.compare(project.starts_on, Date.utc_today()) == :lt -> "bg-amber-100 text-amber-800"
      true -> "bg-green-100 text-green-800"
    end
  end

  defp status_label(project) do
    cond do
      !project.is_active -> "Inactive"
      project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt -> "Completed"
      project.starts_on && Date.compare(project.starts_on, Date.utc_today()) == :lt -> "In Progress"
      true -> "Active"
    end
  end

  defp org_options(orgs), do: [{"Select Organization", ""} | Enum.map(orgs, &{&1.name, &1.id})]
  defp dept_options(depts), do: [{"Select Department", ""} | Enum.map(depts, &{&1.name, &1.id})]
  defp prog_options(progs), do: [{"Select Program", ""} | Enum.map(progs, &{&1.name, &1.id})]
  defp sup_options(sups), do: [{"Select Supervisor", ""} | Enum.map(sups, &{(&1.username || &1.email), &1.id})]

  # Date validation
  defp validate_dates(params) do
    starts_on = parse_date(params["starts_on"])
    ends_on = parse_date(params["ends_on"])

    cond do
      is_nil(starts_on) && is_nil(ends_on) -> {:ok, nil}
      is_nil(starts_on) && !is_nil(ends_on) -> {:error, "Start date is required when end date is provided"}
      !is_nil(starts_on) && !is_nil(ends_on) && Date.compare(ends_on, starts_on) == :lt ->
        {:error, "End date must be after start date"}
      true -> {:ok, nil}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(nil), do: nil
  defp safe_int(""), do: nil
  defp safe_int(val) when is_integer(val), do: val
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    date_string = String.trim(date_string)

    cond do
      String.match?(date_string, ~r/^\d{4}-\d{2}-\d{2}$/) -> parse_iso_date(date_string)
      String.match?(date_string, ~r/^\d{1,2}\/\d{1,2}\/\d{4}$/) -> parse_us_date(date_string)
      String.match?(date_string, ~r/^\d{1,2}\.\d{1,2}\.\d{4}$/) -> parse_dotted_date(date_string)
      true -> nil
    end
  end
  defp parse_date(_), do: nil

  defp parse_iso_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>), do: create_date(y, m, d)
  defp parse_iso_date(_), do: nil

  defp parse_us_date(date_string) do
    case String.split(date_string, "/") do
      [m, d, y] -> create_date(y, m, d)
      _ -> nil
    end
  end

  defp parse_dotted_date(date_string) do
    case String.split(date_string, ".") do
      [d, m, y] -> create_date(y, m, d)
      _ -> nil
    end
  end

  defp create_date(year, month, day) do
    with {y, ""} <- Integer.parse(to_string(year)),
         {m, ""} <- Integer.parse(to_string(month)),
         {d, ""} <- Integer.parse(to_string(day)),
         {:ok, date} <- Date.new(y, m, d) do
      date
    else
      _ -> nil
    end
  end
end
