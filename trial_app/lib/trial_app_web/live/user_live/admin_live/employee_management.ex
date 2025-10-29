defmodule TrialAppWeb.AdminLive.EmployeeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Repo}

  @impl true
  def mount(_params, _session, socket) do
    departments = load_departments()
    employees = Orgs.list_employees()

    # Calculate statistics
    active_count = Enum.count(employees, & &1.is_active)
    teams_count =
      departments
      |> Enum.flat_map(& &1.teams)
      |> Enum.uniq_by(& &1.id)
      |> length()

    {:ok,
     socket
     |> assign(:page_title, "Employee Management")
     |> assign(:departments, departments)
     |> assign(:search, "")
     |> assign(:selected_department, "")
     |> assign(:view_mode, "department")
     |> assign(:expanded_departments, %{})
     |> assign(:total_employees, length(employees))
     |> assign(:active_count, active_count)
     |> assign(:teams_count, teams_count)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    {:noreply, assign(socket, :search, String.trim(q))}
  end

  @impl true
  def handle_event("filter_department", %{"filter" => %{"department_id" => dept_id}}, socket) do
    {:noreply, assign(socket, :selected_department, dept_id)}
  end

  @impl true
  def handle_event("toggle_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  @impl true
  def handle_event("toggle_department", %{"id" => dept_id}, socket) do
    expanded_departments = socket.assigns.expanded_departments
    current_state = Map.get(expanded_departments, dept_id, true)
    updated_departments = Map.put(expanded_departments, dept_id, !current_state)

    {:noreply, assign(socket, :expanded_departments, updated_departments)}
  end

  @impl true
  def handle_event("view_employee", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/employees/#{id}")}
  end

  @impl true
  def handle_event("edit_employee", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/employees/#{id}/edit")}
  end

  @impl true
  def handle_event("delete_employee", %{"id" => id}, socket) do
    employee = Orgs.get_employee!(id)

    case Orgs.delete_employee(employee) do
      {:ok, _employee} ->
        # Reload data to reflect changes
        departments = load_departments()
        employees = Orgs.list_employees()
        active_count = Enum.count(employees, & &1.is_active)
        teams_count =
          departments
          |> Enum.flat_map(& &1.teams)
          |> Enum.uniq_by(& &1.id)
          |> length()

        {:noreply,
         socket
         |> assign(:departments, departments)
         |> assign(:total_employees, length(employees))
         |> assign(:active_count, active_count)
         |> assign(:teams_count, teams_count)
         |> put_flash(:info, "Employee removed successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove employee")}
    end
  end

  # Private helper functions
  defp load_departments do
    Orgs.list_departments()
    |> Repo.preload(employees: [:user, :team])
  end

  # Helper: Check if employee matches search query
  defp matches_search?(_employee, ""), do: true
  defp matches_search?(_employee, nil), do: true

  defp matches_search?(employee, query) do
    q = String.downcase(query)

    searchable_fields = [
      employee.name || "",
      employee.email || "",
      employee.role || "",
      employee.position || "",
      (employee.team && employee.team.name) || ""
    ]

    Enum.any?(searchable_fields, fn val ->
      String.contains?(String.downcase(val), q)
    end)
  end

  # Helper: Check if department should be shown based on filters
  def should_show_department?(department, selected_dept, search) do
    dept_matches = selected_dept == "" || to_string(department.id) == selected_dept
    has_matching_employees = Enum.any?(department.employees, &matches_search?(&1, search))

    dept_matches && has_matching_employees
  end

  # Helper: Get filtered employees for list view
  def get_filtered_employees(departments, selected_dept, search) do
    departments
    |> Enum.filter(fn dept ->
      selected_dept == "" || to_string(dept.id) == selected_dept
    end)
    |> Enum.flat_map(fn dept ->
      dept.employees
      |> Enum.filter(&matches_search?(&1, search))
      |> Enum.map(&Map.put(&1, :department_name, dept.name))
    end)
  end

  # Helper: Get CSS classes for role badges
  def get_role_badge_class(role) do
    base_class = "px-3 py-1.5 text-sm rounded-full font-medium inline-block "

    case String.downcase(role || "") do
      "admin" -> base_class <> "bg-purple-100 text-purple-700"
      "manager" -> base_class <> "bg-blue-100 text-blue-700"
      "lead" -> base_class <> "bg-indigo-100 text-indigo-700"
      "developer" -> base_class <> "bg-[#C1C1FF] text-[#3B3B98]"
      "designer" -> base_class <> "bg-pink-100 text-pink-700"
      "engineer" -> base_class <> "bg-cyan-100 text-cyan-700"
      "analyst" -> base_class <> "bg-green-100 text-green-700"
      "qa" -> base_class <> "bg-orange-100 text-orange-700"
      "support" -> base_class <> "bg-yellow-100 text-yellow-700"
      _ -> base_class <> "bg-gray-100 text-gray-700"
    end
  end

  # Helper: Format employee count text
  def format_employee_count(count) do
    case count do
      0 -> "No members"
      1 -> "1 member"
      n -> "#{n} members"
    end
  end

  # Helper: Get status badge class
  def get_status_badge_class(is_active) do
    if is_active do
      "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium bg-emerald-50 text-emerald-700"
    else
      "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium bg-gray-100 text-gray-500"
    end
  end

  # Helper: Get status dot class
  def get_status_dot_class(is_active) do
    if is_active do
      "w-1.5 h-1.5 rounded-full bg-emerald-500"
    else
      "w-1.5 h-1.5 rounded-full bg-gray-400"
    end
  end

  # Helper: Get employee initials
  def get_employee_initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end

  # Helper: Check if department is expanded
  def is_department_expanded?(expanded_departments, dept_id) do
    Map.get(expanded_departments, to_string(dept_id), true)
  end

  @impl true
end
