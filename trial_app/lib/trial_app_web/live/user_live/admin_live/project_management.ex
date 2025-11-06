defmodule TrialAppWeb.AdminLive.ProjectManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}
  alias TrialApp.Accounts

  # Mount
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:projects, list_projects_with_preloads())
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_project, nil)
     |> assign(:viewing_project, nil)
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:supervisors, Accounts.list_users_by_role("admin") ++ Accounts.list_users_by_role("manager"))
     |> assign(:form_data, empty_form())
     |> assign(:errors, %{})}
  end

  # Events - Create
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_project, nil)
     |> assign(:form_data, empty_form())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:errors, %{})}
  end

  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_project, nil)
     |> assign(:viewing_project, nil)
     |> assign(:form_data, empty_form())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:errors, %{})}
  end

  def handle_event("update", %{"project" => params}, socket) do
    org_id = Map.get(params, "organization_id")
    dept_id = Map.get(params, "department_id")

    org_int = safe_int(org_id)
    dept_int = safe_int(dept_id)

    departments = if is_integer(org_int), do: Orgs.list_departments_by_org(org_int), else: []
    programs = if is_integer(dept_int), do: Eams.list_programs_by_department(dept_int), else: []

    # Clear date validation errors when dates change
    errors = socket.assigns.errors
    |> Map.delete(:starts_on)
    |> Map.delete(:ends_on)
    |> Map.delete(:date_range)

    {:noreply,
     socket
     |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
     |> assign(:departments, departments)
     |> assign(:programs, programs)
     |> assign(:errors, errors)}
  end

  def handle_event("save", %{"project" => params}, socket) do
    require Logger

    # Log what we received
    Logger.info("Attempting to save project with params: #{inspect(params)}")

    # Validate dates first
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

        Logger.info("Parsed attributes: #{inspect(attrs)}")

        result = if socket.assigns.editing_project do
          Eams.update_project(socket.assigns.editing_project, attrs)
        else
          Eams.create_project(attrs)
        end

        case result do
          {:ok, project} ->
            Logger.info("Project saved successfully: #{inspect(project)}")
            {:noreply,
             socket
             |> assign(:show_form, false)
             |> assign(:editing_project, nil)
             |> assign(:form_data, empty_form())
             |> assign(:departments, [])
             |> assign(:programs, [])
             |> assign(:projects, list_projects_with_preloads())
             |> assign(:errors, %{})
             |> put_flash(:info, "Project #{if socket.assigns.editing_project, do: "updated", else: "created"} successfully")}

          {:error, %Ecto.Changeset{} = changeset} ->
            Logger.error("Failed to save project. Changeset errors: #{inspect(changeset.errors)}")
            errors = changeset.errors |> Enum.into(%{})
            Logger.error("Formatted errors: #{inspect(errors)}")
            {:noreply, assign(socket, errors: errors)}

          {:error, reason} ->
            Logger.error("Failed to save project. Reason: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to save project: #{inspect(reason)}")}
        end

      {:error, message} ->
        Logger.error("Date validation failed: #{message}")
        {:noreply, assign(socket, errors: %{date_range: message})}
    end
  end

  # Events - View
  def handle_event("view_project", %{"id" => id}, socket) do
    project = Eams.get_project!(parse_int(id))
              |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor])

    {:noreply,
     socket
     |> assign(:viewing_project, project)
     |> assign(:show_view_modal, true)}
  end

  # Events - Edit
  def handle_event("edit_project", %{"id" => id}, socket) do
    project = Eams.get_project!(parse_int(id))
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
     |> assign(:form_data, form_data)
     |> assign(:departments, departments)
     |> assign(:programs, programs)
     |> assign(:errors, %{})}
  end

  # Events - Delete
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

  # Helpers
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

  defp validate_dates(params) do
    starts_on = parse_date(params["starts_on"])
    ends_on = parse_date(params["ends_on"])

    cond do
      is_nil(starts_on) and is_nil(ends_on) ->
        {:ok, nil}

      is_nil(starts_on) and not is_nil(ends_on) ->
        {:error, "Start date is required when end date is provided"}

      not is_nil(starts_on) and not is_nil(ends_on) and Date.compare(ends_on, starts_on) == :lt ->
        {:error, "End date must be after start date"}

      true ->
        {:ok, nil}
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

  # Handle multiple date formats
  defp parse_date(date_string) when is_binary(date_string) do
    date_string = String.trim(date_string)

    cond do
      # ISO format: YYYY-MM-DD
      String.match?(date_string, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        parse_iso_date(date_string)

      # US format: MM/DD/YYYY
      String.match?(date_string, ~r/^\d{1,2}\/\d{1,2}\/\d{4}$/) ->
        parse_us_date(date_string)

      # European format: DD/MM/YYYY
      String.match?(date_string, ~r/^\d{1,2}\/\d{1,2}\/\d{4}$/) ->
        parse_european_date(date_string)

      # Dotted format: DD.MM.YYYY
      String.match?(date_string, ~r/^\d{1,2}\.\d{1,2}\.\d{4}$/) ->
        parse_dotted_date(date_string)

      true ->
        nil
    end
  end

  defp parse_date(_), do: nil

  # Parse ISO format: YYYY-MM-DD
  defp parse_iso_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    create_date(y, m, d)
  end
  defp parse_iso_date(_), do: nil

  # Parse US format: MM/DD/YYYY
  defp parse_us_date(date_string) do
    case String.split(date_string, "/") do
      [m, d, y] -> create_date(y, m, d)
      _ -> nil
    end
  end

  # Parse European format: DD/MM/YYYY
  defp parse_european_date(date_string) do
    case String.split(date_string, "/") do
      [d, m, y] -> create_date(y, m, d)
      _ -> nil
    end
  end

  # Parse dotted format: DD.MM.YYYY
  defp parse_dotted_date(date_string) do
    case String.split(date_string, ".") do
      [d, m, y] -> create_date(y, m, d)
      _ -> nil
    end
  end

  # Helper to safely create a date
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
