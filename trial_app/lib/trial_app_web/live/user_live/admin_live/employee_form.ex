defmodule TrialAppWeb.AdminLive.EmployeeForm do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Orgs.Employee.create_changeset(%Orgs.Employee{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "Add New Employee")
     |> assign(:form, to_form(changeset))
     |> assign(:organizations, load_organizations())
     |> assign(:departments, [])
     |> assign(:teams, [])
     |> assign(:users, load_users())
     |> assign(:positions, Orgs.list_positions())
     |> assign(:selected_org_id, nil)
     |> assign(:selected_dept_id, nil)}
  end

  @impl true
  def handle_event("validate", %{"employee" => employee_params}, socket) do
    changeset =
      %Orgs.Employee{}
      |> Orgs.Employee.create_changeset(employee_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("organization_selected", %{"org_select" => org_id}, socket) do
    org_int = safe_int(org_id)
    departments = if is_integer(org_int), do: Orgs.list_departments_by_org(org_int), else: []

    {:noreply,
     socket
     |> assign(:selected_org_id, org_id)
     |> assign(:departments, departments)
     |> assign(:teams, [])
     |> assign(:selected_dept_id, nil)}
  end

  @impl true
  def handle_event("department_selected", %{"dept_select" => dept_id}, socket) do
    dept_int = safe_int(dept_id)
    teams = if is_integer(dept_int), do: Orgs.list_teams_by_dept(dept_int), else: []

    {:noreply,
     socket
     |> assign(:selected_dept_id, dept_id)
     |> assign(:teams, teams)}
  end

  @impl true
  def handle_event("save", %{"employee" => employee_params}, socket) do
    case Orgs.create_employee(employee_params) do
      {:ok, _employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee created successfully")
         |> push_navigate(to: ~p"/admin/employees")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/employees")}
  end

  defp load_organizations do
    Orgs.list_organizations()
  end

  defp load_users do
    Accounts.list_users()
  end

  defp safe_int(nil), do: nil
  defp safe_int(""), do: nil

  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end
end
