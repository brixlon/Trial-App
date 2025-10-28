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

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <div class="max-w-7xl mx-auto">
        <div class="bg-base-100 border border-base-300 rounded-xl shadow-sm p-6">
              <%= if @user_status == "pending" do %>
              <!-- Pending Approval View -->
              <div class="text-center py-16">
                <div class="max-w-md mx-auto">
                  <div class="w-20 h-20 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6">
                    <svg
                      class="w-10 h-10 text-yellow-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      >
                      </path>
                    </svg>
                  </div>
                  <h1 class="text-2xl font-bold text-gray-900 mb-4">Access Restricted</h1>
                  <p class="text-gray-600 mb-6">
                    Your account is pending administrator approval.
                    You'll gain access to employee information once your roles are assigned.
                  </p>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left">
                    <h3 class="font-semibold text-blue-800 mb-2">What you'll see after approval:</h3>
                    <ul class="text-blue-700 text-sm space-y-1">
                      <li>• Your personal employee record</li>
                      <li>• Your position and department details</li>
                      <li>• Your employee ID and contract information</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Active User Employees View -->
              <h1 class="text-3xl font-bold mb-8">Employees</h1>

              <div class="mb-6 p-4 bg-base-200 rounded-lg border border-base-300">
                <h2 class="text-lg font-semibold">
                  Total Employees: <span class="text-2xl">{@total_employees}</span>
                </h2>
                <p class="text-base-content/70 text-sm mt-1">You can only view your own employee information</p>
              </div>

              <%= if @current_user_employee do %>
                <div class="mb-8">
                  <h2 class="text-xl font-semibold text-gray-700 mb-4">Your Employee Information</h2>
                  <div class="rounded-lg border border-base-300 bg-base-100">
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 p-4">
                      <div>
                        <div class="text-sm text-gray-500">Name</div>
                        <div class="font-medium text-gray-800">{@current_user_employee.name}</div>
                      </div>
                      <div>
                        <div class="text-sm text-gray-500">Position</div>
                        <div class="text-gray-800">{@current_user_employee.position}</div>
                      </div>
                      <div>
                        <div class="text-sm text-base-content/70">Department</div>
                        <div class="text-base-content">{@current_user_employee.department && @current_user_employee.department.name}</div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <div id="departments" phx-update="stream" class="space-y-8">
                <%= for {section_id, dept} <- @streams.departments do %>
                  <section id={section_id} class="border border-base-300 rounded-xl shadow-sm bg-base-100">
                    <header class="px-6 py-4 border-b border-base-300 rounded-t-xl">
                      <h3 class="text-lg font-semibold">{dept.name}</h3>
                      <p class="text-sm text-base-content/70">{dept.description}</p>
                    </header>
                    <div class="overflow-x-auto">
                      <table class="w-full table-auto">
                        <thead>
                          <tr class="bg-base-200">
                            <th class="p-3 text-left">Employee</th>
                            <th class="p-3 text-left">Email</th>
                            <th class="p-3 text-left">Team</th>
                            <th class="p-3 text-left">Position</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for emp <- dept.employees do %>
                            <tr class="border-b border-base-300 hover:bg-base-100">
                              <td class="p-3 font-medium">{emp.name}</td>
                              <td class="p-3 text-base-content/70">{emp.email}</td>
                              <td class="p-3">{emp.team && emp.team.name}</td>
                              <td class="p-3">{emp.position}</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                      <div class={["p-4 text-base-content/60", (dept.employees == [] && "block") || "hidden"]}>No employees</div>
                    </div>
                  </section>
                <% end %>
              </div>
            <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
