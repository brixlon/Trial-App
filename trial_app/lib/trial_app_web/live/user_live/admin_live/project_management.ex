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
     |> assign(:programs, [])}
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
     |> assign(:programs, [])}
  end

  def handle_event("update", %{"project" => params}, socket) do
    org_id = Map.get(params, "organization_id")
    dept_id = Map.get(params, "department_id")

    org_int = safe_int(org_id)
    dept_int = safe_int(dept_id)

    departments = if is_integer(org_int), do: Orgs.list_departments_by_org(org_int), else: []
    programs = if is_integer(dept_int), do: Eams.list_programs_by_department(dept_int), else: []

    {:noreply,
     socket
     |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  def handle_event("save", %{"project" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      code: params["code"],
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      organization_id: parse_int(params["organization_id"]),
      department_id: parse_int(params["department_id"]),
      program_id: parse_int(params["program_id"]),
      supervisor_id: parse_int(params["supervisor_id"])
    }

    result = if socket.assigns.editing_project do
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
         |> assign(:form_data, empty_form())
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> assign(:projects, list_projects_with_preloads())
         |> put_flash(:info, "Project #{if socket.assigns.editing_project, do: "updated", else: "created"} successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, errors: changeset.errors |> Enum.into(%{}))}
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
     |> assign(:programs, programs)}
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

  defp parse_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    case Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
