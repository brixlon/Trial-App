defmodule TrialAppWeb.DepartmentLive.Index do
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
      # User is active, show department data
      # (Mock data for now)
      all_departments = [
        %{id: 1, name: "Engineering", description: "Software development"},
        %{id: 2, name: "HR", description: "Human resources"},
        %{id: 3, name: "Marketing", description: "Marketing and sales"},
        %{id: 4, name: "Finance", description: "Financial operations"}
      ]

      # User's assigned department (mock)
      user_department = %{id: 1, name: "Engineering", description: "Software development"}

      {:ok,
       socket
       |> assign(:user_status, "active")
       |> assign(:has_assignments, true)
       |> assign(:total_departments, length(all_departments))
       |> assign(:user_department, user_department)
       |> stream(:departments, [user_department])}
    end
  end
end
