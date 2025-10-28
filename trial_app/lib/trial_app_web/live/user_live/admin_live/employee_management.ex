defmodule TrialAppWeb.AdminLive.EmployeeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Organizations
  alias TrialApp.Employees.Employee

  @impl true
  def mount(_params, _session, socket) do
    employees = Organizations.list_all_employees()
    departments = Organizations.list_all_departments()
    teams = Organizations.list_all_teams()

    {:ok,
     socket
     |> assign(:employees, employees)
     |> assign(:departments, departments)
     |> assign(:teams, teams)
     |> assign(:show_form, false)
     |> assign(:form, to_form(Employee.changeset(%Employee{}, %{})))
     |> assign(:search_query, "")
     |> assign(:editing_id, nil)
     |> assign(:show_delete_modal, false)
     |> assign(:deleting_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-50">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />

      <main class="flex-1 overflow-y-auto ml-64">
        <!-- Header Bar -->
        <div class="bg-white border-b border-gray-200 sticky top-0 z-10">
          <div class="px-8 py-6">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-gray-900 flex items-center gap-3">
                  <span class="text-4xl">👥</span>
                  Employee Management
                </h1>
                <p class="text-gray-600 mt-2">Manage employee records and team assignments</p>
              </div>
              <button
                phx-click="new_employee"
                class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg hover:shadow-xl font-semibold"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                Add Employee
              </button>
            </div>
          </div>
        </div>

        <!-- Content Area -->
        <div class="p-8">
          <div class="max-w-7xl mx-auto">
            <!-- Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
              <div class="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-purple-100 text-sm font-semibold">Total Employees</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@employees) %></p>
                  </div>
                  <div class="text-5xl opacity-50">👥</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-blue-100 text-sm font-semibold">Departments</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@departments) %></p>
                  </div>
                  <div class="text-5xl opacity-50">🏛️</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-green-100 text-sm font-semibold">Teams</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@teams) %></p>
                  </div>
                  <div class="text-5xl opacity-50">🎯</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-orange-100 text-sm font-semibold">Active</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@employees) %></p>
                  </div>
                  <div class="text-5xl opacity-50">✅</div>
                </div>
              </div>
            </div>

            <!-- Search Bar -->
            <div class="bg-white rounded-xl shadow-sm p-4 mb-6">
              <div class="relative">
                <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <input
                  type="text"
                  phx-change="search"
                  name="query"
                  value={@search_query}
                  placeholder="Search employees by name, email, or role..."
                  class="w-full pl-10 pr-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                />
              </div>
            </div>

            <!-- Employees Grid -->
            <%= if Enum.empty?(@employees) do %>
              <!-- Empty State -->
              <div class="bg-white rounded-2xl shadow-sm p-16 text-center">
                <div class="max-w-md mx-auto">
                  <div class="text-7xl mb-6">👥</div>
                  <h3 class="text-2xl font-bold text-gray-900 mb-2">No Employees Yet</h3>
                  <p class="text-gray-600 mb-8">
                    Get started by adding your first employee to build your team.
                  </p>
                  <%= if Enum.empty?(@departments) or Enum.empty?(@teams) do %>
                    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
                      <p class="text-yellow-800 text-sm mb-3">
                        ⚠️ You need departments and teams before adding employees.
                      </p>
                      <div class="flex gap-3 justify-center">
                        <%= if Enum.empty?(@departments) do %>
                          <.link
                            navigate={~p"/admin/departments"}
                            class="px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-all font-semibold text-sm"
                          >
                            Create Departments
                          </.link>
                        <% end %>
                        <%= if Enum.empty?(@teams) do %>
                          <.link
                            navigate={~p"/admin/teams"}
                            class="px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-all font-semibold text-sm"
                          >
                            Create Teams
                          </.link>
                        <% end %>
                      </div>
                    </div>
                  <% else %>
                    <button
                      phx-click="new_employee"
                      class="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg font-semibold"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                      </svg>
                      Add First Employee
                    </button>
                  <% end %>
                </div>
              </div>
            <% else %>
              <!-- Employees Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for employee <- @employees do %>
                  <div class="bg-white rounded-xl shadow-sm hover:shadow-lg transition-all border-2 border-gray-100 hover:border-purple-200 p-6 group">
                    <div class="flex items-start justify-between mb-4">
                      <div class="flex items-center gap-3 flex-1">
                        <div class="w-14 h-14 bg-gradient-to-br from-purple-500 to-pink-500 rounded-full flex items-center justify-center text-white text-xl font-bold">
                          <%= String.first(employee.name) |> String.upcase() %>
                        </div>
                        <div class="flex-1 min-w-0">
                          <h3 class="font-bold text-lg text-gray-900 group-hover:text-purple-600 transition-colors truncate">
                            <%= employee.name %>
                          </h3>
                          <span class="text-sm text-purple-600 font-medium"><%= employee.role || "No role" %></span>
                        </div>
                      </div>
                      <div class="flex gap-1">
                        <button
                          phx-click="edit_employee"
                          phx-value-id={employee.id}
                          class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                          title="Edit Employee"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                          </svg>
                        </button>
                        <button
                          phx-click="show_delete_modal"
                          phx-value-id={employee.id}
                          class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete Employee"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                          </svg>
                        </button>
                      </div>
                    </div>

                    <div class="space-y-2.5 text-sm text-gray-600">
                      <div class="flex items-center gap-2">
                        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                        </svg>
                        <span class="truncate"><%= employee.email %></span>
                      </div>
                      <%= if employee.position do %>
                        <div class="flex items-center gap-2">
                          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m8 0h5a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2h5"/>
                          </svg>
                          <span class="truncate"><%= employee.position %></span>
                        </div>
                      <% end %>
                    </div>

                    <div class="mt-4 pt-4 border-t border-gray-100 flex items-center justify-between text-xs">
                      <div class="flex items-center gap-1.5 text-gray-500">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                        </svg>
                        <span class="truncate"><%= employee.department.name %></span>
                      </div>
                      <div class="flex items-center gap-1.5 text-gray-500">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                        </svg>
                        <span class="truncate"><%= employee.team.name %></span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </main>

      <!-- Add/Edit Employee Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-3xl shadow-2xl transform transition-all max-h-[90vh] overflow-y-auto">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white rounded-t-2xl z-10">
              <div class="flex items-center gap-3">
                <div class="w-12 h-12 bg-gradient-to-br from-purple-500 to-pink-500 rounded-xl flex items-center justify-center text-2xl">
                  👤
                </div>
                <div>
                  <h2 class="text-2xl font-bold text-gray-900">
                    <%= if @editing_id, do: "Edit Employee", else: "Add New Employee" %>
                  </h2>
                  <p class="text-sm text-gray-500 mt-0.5">Fill in the employee information below</p>
                </div>
              </div>
              <button
                phx-click="hide_modal"
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Modal Body -->
            <.form for={@form} phx-submit="save_employee" phx-change="validate_employee" class="p-6">
              <!-- Personal Information Section -->
              <div class="mb-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                  <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                  </svg>
                  Personal Information
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">
                      Full Name *
                    </label>
                    <input
                      type="text"
                      name="employee[name]"
                      value={Phoenix.HTML.Form.input_value(@form, :name)}
                      placeholder="e.g., John Doe"
                      class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">
                      Email Address *
                    </label>
                    <input
                      type="email"
                      name="employee[email]"
                      value={Phoenix.HTML.Form.input_value(@form, :email)}
                      placeholder="e.g., john.doe@company.com"
                      class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                      required
                    />
                  </div>
                </div>
              </div>

              <!-- Job Information Section -->
              <div class="mb-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                  <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m8 0h5a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2h5"/>
                  </svg>
                  Job Information
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">
                      Role *
                    </label>
                    <input
                      type="text"
                      name="employee[role]"
                      value={Phoenix.HTML.Form.input_value(@form, :role)}
                      placeholder="e.g., Senior Developer, Manager"
                      class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">
                      Position
                    </label>
                    <input
                      type="text"
                      name="employee[position]"
                      value={Phoenix.HTML.Form.input_value(@form, :position)}
                      placeholder="e.g., Software Engineer"
                      class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                    />
                  </div>
                </div>
              </div>

              <!-- Assignment Section -->
              <div class="mb-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                  <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                  </svg>
                  Department & Team Assignment
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">
                      Department *
                    </label>
                    <select
                      name="employee[department_id]"
                      class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                      required
                    >
                      <option value="">Select Department</option>
                      <%= for dept <- @departments do %>
                        <option value={dept.id} selected={Phoenix.HTML.Form.input_value(@form, :department_id) == dept.id}>
                          <%= dept.name %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <div>
                    <label class="block text-sm font-semibold text-gray-700 mb-2">
                      Team *
                    </label>
                    <select
                      name="employee[team_id]"
                      class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
                      required
                    >
                      <option value="">Select Team</option>
                      <%= for team <- @teams do %>
                        <option value={team.id} selected={Phoenix.HTML.Form.input_value(@form, :team_id) == team.id}>
                          <%= team.name %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>
              </div>

              <!-- Modal Footer -->
              <div class="flex justify-end gap-3 pt-6 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="hide_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg font-semibold"
                >
                  <%= if @editing_id, do: "Update Employee", else: "Create Employee" %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Delete Confirmation Modal -->
      <%= if @show_delete_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-md shadow-2xl transform transition-all">
            <div class="p-6 text-center">
              <!-- Warning Icon -->
              <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-1.964-1.333-2.732 0L4.35 16c-.77 1.333.192 3 1.732 3z"/>
                </svg>
              </div>

              <h3 class="text-xl font-bold text-gray-900 mb-2">Delete Employee</h3>
              <p class="text-gray-600 mb-6">
                Are you sure you want to delete this employee? This action cannot be undone.
              </p>

              <div class="flex justify-center gap-3">
                <button
                  phx-click="hide_delete_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  phx-click="delete_employee"
                  phx-value-id={@deleting_id}
                  class="px-6 py-3 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-all shadow-lg font-semibold"
                >
                  Delete Employee
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # === Event Handlers ===

  @impl true
  def handle_event("new_employee", _params, socket) do
    {:noreply, assign(socket,
      show_form: true,
      editing_id: nil,
      form: to_form(Employee.changeset(%Employee{}, %{}))
    )}
  end

  @impl true
  def handle_event("edit_employee", %{"id" => id}, socket) do
    employee = Organizations.get_employee!(String.to_integer(id))
    {:noreply, assign(socket,
      show_form: true,
      editing_id: String.to_integer(id),
      form: to_form(Employee.changeset(employee, %{}))
    )}
  end

  @impl true
  def handle_event("hide_modal", _params, socket) do
    {:noreply, assign(socket,
      show_form: false,
      editing_id: nil,
      form: to_form(Employee.changeset(%Employee{}, %{}))
    )}
  end

  @impl true
  def handle_event("validate_employee", %{"employee" => employee_params}, socket) do
    changeset = Employee.changeset(%Employee{}, employee_params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save_employee", %{"employee" => employee_params}, socket) do
    if socket.assigns.editing_id do
      employee = Organizations.get_employee!(socket.assigns.editing_id)
      case Organizations.update_employee(employee, employee_params) do
        {:ok, _employee} ->
          employees = Organizations.list_all_employees()
          {:noreply,
            socket
            |> assign(show_form: false, editing_id: nil, form: to_form(Employee.changeset(%Employee{}, %{})))
            |> assign(employees: employees)
            |> put_flash(:info, "✅ Employee updated successfully!")
          }
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      case Organizations.create_employee(employee_params) do
        {:ok, _employee} ->
          employees = Organizations.list_all_employees()
          {:noreply,
            socket
            |> assign(show_form: false, form: to_form(Employee.changeset(%Employee{}, %{})))
            |> assign(employees: employees)
            |> put_flash(:info, "✅ Employee created successfully!")
          }
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  @impl true
  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket,
      show_delete_modal: true,
      deleting_id: String.to_integer(id)
    )}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket,
      show_delete_modal: false,
      deleting_id: nil
    )}
  end

  @impl true
  def handle_event("delete_employee", %{"id" => id}, socket) do
    employee = Organizations.get_employee!(String.to_integer(id))
    case Organizations.delete_employee(employee) do
      {:ok, _employee} ->
        employees = Organizations.list_all_employees()
        {:noreply,
          socket
          |> assign(employees: employees, show_delete_modal: false, deleting_id: nil)
          |> put_flash(:info, "🗑️ Employee '#{employee.name}' deleted successfully!")
        }
      {:error, _changeset} ->
        {:noreply,
          socket
          |> assign(show_delete_modal: false, deleting_id: nil)
          |> put_flash(:error, "Failed to delete employee")
        }
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end
end
