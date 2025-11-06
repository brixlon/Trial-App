defmodule TrialAppWeb.AdminLive.ProjectManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}
  alias TrialApp.Accounts

  # Mount
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:projects, Eams.list_projects())
     |> assign(:show_form, false)
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:supervisors, Accounts.list_users_by_role("admin") ++ Accounts.list_users_by_role("manager"))
     |> assign(:form_data, empty_form())
     |> assign(:errors, %{})}
  end

  # Events
  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, show_form: false, form_data: empty_form())}
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

    case Eams.create_project(attrs) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form_data, empty_form())
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> assign(:projects, Eams.list_projects())}

      {:error, changeset} ->
        {:noreply, assign(socket, errors: changeset.errors |> Enum.into(%{}))}
    end
  end

  # Helpers
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
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(nil), do: nil
  defp safe_int(""), do: nil
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
