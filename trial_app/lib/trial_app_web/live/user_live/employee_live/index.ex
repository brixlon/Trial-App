defmodule TrialAppWeb.EmployeeLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Check if user is pending approval
    if current_user.status == "pending" do
      {:ok,
        socket
        |> assign(:user_status, "pending")
        |> assign(:has_assignments, false)
      }
    else
      # User is active, show employee data
      # Mock data - in real app, this would come from database
      # For now, we'll simulate: total employees = 50, user's info = John Doe
      all_employees = [
        %{id: 1, first_name: "John", last_name: "Doe", position: "Senior Developer", department: "Engineering", position_id: 101, department_id: 1},
        %{id: 2, first_name: "Jane", last_name: "Smith", position: "HR Manager", department: "HR", position_id: 102, department_id: 2}
        # ... 48 more employees in real app
      ]

      # Current user's employee info (in real app, this would come from user context)
      current_user_employee = %{id: 1, first_name: "John", last_name: "Doe", position: "Senior Developer", department: "Engineering", position_id: 101, department_id: 1}

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, true)
       |> assign(:total_employees, 50) # Mock total count
       |> assign(:current_user_employee, current_user_employee)
       |> stream(:employees, [current_user_employee])}
    end
  end
end
