defmodule TrialAppWeb.EmployeeLive.Index do
  use TrialAppWeb, :live_view
  alias TrialApp.Orgs

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:page_title, "Employees")
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)}
    else
      # Load departments with employees preloaded
      departments = Orgs.list_departments()
      employees = Orgs.list_employees()

      current_user_employee =
        employees
        |> Enum.find(fn e -> e.user_id == current_user.id end)

      # Preload department for current user employee
      current_user_employee =
        if current_user_employee do
          TrialApp.Repo.preload(current_user_employee, [:department, :team])
        else
          nil
        end

      # Calculate stats
      active_count = Enum.count(employees, & &1.is_active)
      teams_count = departments |> Enum.flat_map(& &1.teams) |> Enum.uniq_by(& &1.id) |> length()

      {:ok,
       socket
       |> assign(:page_title, "Employees")
       |> assign(:user_status, "active")
       |> assign(:has_assignments, current_user_employee != nil)
       |> assign(:total_employees, length(employees))
       |> assign(:active_count, active_count)
       |> assign(:teams_count, teams_count)
       |> assign(:current_user_employee, current_user_employee)
       |> assign(:departments, departments)
       |> assign(:search, "")
       |> assign(:selected_department, "")
       |> assign(:view_mode, "department")
       |> assign(:expanded_departments, %{})
       |> assign(:show_profile_modal, false)}
    end
  end

  # Search handler
  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    {:noreply, assign(socket, :search, query)}
  end

  # Department filter handler
  def handle_event("filter_department", %{"filter" => %{"department_id" => dept_id}}, socket) do
    {:noreply, assign(socket, :selected_department, dept_id)}
  end

  # View toggle handler
  def handle_event("toggle_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  # Department collapse/expand handler
  def handle_event("toggle_department", %{"id" => dept_id}, socket) do
    expanded_departments = socket.assigns.expanded_departments
    current_state = Map.get(expanded_departments, dept_id, true)
    updated_departments = Map.put(expanded_departments, dept_id, !current_state)

    {:noreply, assign(socket, :expanded_departments, updated_departments)}
  end

  # Toggle profile modal
  def handle_event("toggle_profile_modal", _params, socket) do
    {:noreply, assign(socket, :show_profile_modal, !socket.assigns.show_profile_modal)}
  end

  # Helper functions
  def matches_search?(employee, search) when search == "" or is_nil(search), do: true

  def matches_search?(employee, search) do
    search = String.downcase(search)

    String.contains?(String.downcase(employee.name || ""), search) ||
      String.contains?(String.downcase(employee.email || ""), search) ||
      String.contains?(String.downcase(employee.role || ""), search) ||
      String.contains?(String.downcase(employee.position || ""), search) ||
      (employee.team && String.contains?(String.downcase(employee.team.name || ""), search))
  end

  def should_show_department?(department, selected_dept, search) do
    dept_matches = selected_dept == "" || to_string(department.id) == selected_dept
    has_matching_employees = Enum.any?(department.employees, &matches_search?(&1, search))

    dept_matches && has_matching_employees
  end

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
      _ -> base_class <> "bg-gray-100 text-gray-700"
    end
  end

  def format_employee_count(count) do
    case count do
      0 -> "No members"
      1 -> "1 member"
      n -> "#{n} members"
    end
  end

  def get_status_badge_class(is_active) do
    if is_active do
      "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium bg-emerald-50 text-emerald-700"
    else
      "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium bg-gray-100 text-gray-500"
    end
  end

  def get_status_dot_class(is_active) do
    if is_active do
      "w-1.5 h-1.5 rounded-full bg-emerald-500"
    else
      "w-1.5 h-1.5 rounded-full bg-gray-400"
    end
  end

  def get_employee_initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end

  def is_department_expanded?(expanded_departments, dept_id) do
    Map.get(expanded_departments, to_string(dept_id), true)
  end
end
