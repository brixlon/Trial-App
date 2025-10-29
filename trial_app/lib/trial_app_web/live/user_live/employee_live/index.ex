defmodule TrialAppWeb.EmployeeLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    alias TrialApp.Orgs

    if current_user.status == "pending" do
      {:ok,
       socket
       |> assign(:page_title, "Employees")
       |> assign(:user_status, "pending")
       |> assign(:has_assignments, false)}
    else
      # Load departments with employees preloaded and group in UI
      departments = Orgs.list_departments()
      employees = Orgs.list_employees()

      current_user_employee =
        employees
        |> Enum.find(fn e -> e.user_id == current_user.id end)

      {:ok,
       socket
       |> assign(:page_title, "Employees")
       |> assign(:user_status, "active")
       |> assign(:has_assignments, current_user_employee != nil)
       |> assign(:total_employees, length(employees))
       |> assign(:current_user_employee, current_user_employee)
       |> stream(:departments, departments)}
    end
  end
end
