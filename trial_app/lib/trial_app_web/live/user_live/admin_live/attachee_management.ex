defmodule TrialAppWeb.AdminLive.AttacheeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Repo, Eams, Orgs, Accounts}
  alias TrialApp.Eams.Attachee

  # Mount initial assigns
  def mount(_params, _session, socket) do
    organizations = Orgs.list_organizations()
    users = Accounts.list_users()
    attachees = Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})

    # Create a changeset for a new attachee
    changeset = Attachee.changeset(%Attachee{}, %{})

    {:ok,
     assign(socket,
       form: to_form(changeset),
       organizations: organizations,
       departments: [],
       programs: [],
       users: users,
       attachees: attachees,
       show_form: false
     )}
  end

  # Render template
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <!-- Sidebar -->
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <!-- Main content -->
        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-8">
            <!-- Header -->
            <div class="flex items-center justify-between">
              <h1 class="text-2xl font-semibold text-gray-800">Attachee Management</h1>
              <button
                phx-click="toggle_form"
                class="bg-purple-600 text-white px-4 py-2 rounded-lg shadow hover:bg-purple-700"
              >
                <%= if @show_form, do: "Close Form", else: "Add Attachee" %>
              </button>
            </div>

            <!-- Attachee Form -->
            <%= if @show_form do %>
              <div class="bg-gray-50 p-6 rounded-xl shadow">
                <.form for={@form} phx-submit="save" phx-change="update">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium">User</label>
                      <select name="attachee[user_id]" class="w-full border-gray-300 rounded-lg">
                        <option value="">Select User</option>
                        <%= for user <- @users do %>
                          <option value={user.id} selected={@form.params["user_id"] == to_string(user.id)}>
                            <%= user.username %>
                          </option>
                        <% end %>
                      </select>
                      <%= if @form[:user_id].errors != [] do %>
                        <p class="mt-1 text-sm text-red-600">
                          <%= translate_errors(@form[:user_id].errors) %>
                        </p>
                      <% end %>
                    </div>

                    <div>
                      <label class="block text-sm font-medium">Organization</label>
                      <select
                        name="attachee[organization_id]"
                        phx-change="update"
                        class="w-full border-gray-300 rounded-lg"
                      >
                        <option value="">Select Organization</option>
                        <%= for org <- @organizations do %>
                          <option value={org.id} selected={@form.params["organization_id"] == to_string(org.id)}>
                            <%= org.name %>
                          </option>
                        <% end %>
                      </select>
                      <%= if @form[:organization_id].errors != [] do %>
                        <p class="mt-1 text-sm text-red-600">
                          <%= translate_errors(@form[:organization_id].errors) %>
                        </p>
                      <% end %>
                    </div>

                    <div>
                      <label class="block text-sm font-medium">Department</label>
                      <select
                        name="attachee[department_id]"
                        phx-change="update"
                        class="w-full border-gray-300 rounded-lg"
                      >
                        <option value="">Select Department</option>
                        <%= for dept <- @departments do %>
                          <option value={dept.id} selected={@form.params["department_id"] == to_string(dept.id)}>
                            <%= dept.name %>
                          </option>
                        <% end %>
                      </select>
                      <%= if @form[:department_id].errors != [] do %>
                        <p class="mt-1 text-sm text-red-600">
                          <%= translate_errors(@form[:department_id].errors) %>
                        </p>
                      <% end %>
                    </div>

                    <div>
                      <label class="block text-sm font-medium">Program</label>
                      <select name="attachee[program_id]" class="w-full border-gray-300 rounded-lg">
                        <option value="">Select Program</option>
                        <%= for prog <- @programs do %>
                          <option value={prog.id} selected={@form.params["program_id"] == to_string(prog.id)}>
                            <%= prog.name %>
                          </option>
                        <% end %>
                      </select>
                    </div>

                    <div>
                      <label class="block text-sm font-medium">Start Date</label>
                      <input
                        type="date"
                        name="attachee[starts_on]"
                        value={@form.params["starts_on"]}
                        class="w-full border-gray-300 rounded-lg"
                      />
                      <%= if @form[:starts_on].errors != [] do %>
                        <p class="mt-1 text-sm text-red-600">
                          <%= translate_errors(@form[:starts_on].errors) %>
                        </p>
                      <% end %>
                    </div>

                    <div>
                      <label class="block text-sm font-medium">End Date</label>
                      <input
                        type="date"
                        name="attachee[ends_on]"
                        value={@form.params["ends_on"]}
                        class="w-full border-gray-300 rounded-lg"
                      />
                      <%= if @form[:ends_on].errors != [] do %>
                        <p class="mt-1 text-sm text-red-600">
                          <%= translate_errors(@form[:ends_on].errors) %>
                        </p>
                      <% end %>
                    </div>
                  </div>

                  <div class="mt-6 flex justify-end">
                    <button
                      type="submit"
                      class="bg-green-600 text-white px-4 py-2 rounded-lg shadow hover:bg-green-700"
                    >
                      Save Attachee
                    </button>
                  </div>
                </.form>
              </div>
            <% end %>

            <!-- Attachee List -->
            <div class="bg-white shadow rounded-xl overflow-hidden">
              <table class="min-w-full text-sm text-left text-gray-700">
                <thead class="bg-gray-100 text-xs uppercase">
                  <tr>
                    <th class="px-4 py-3">User</th>
                    <th class="px-4 py-3">Organization</th>
                    <th class="px-4 py-3">Department</th>
                    <th class="px-4 py-3">Program(s)</th>
                    <th class="px-4 py-3">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for attachee <- @attachees do %>
                    <tr class="border-t">
                      <td class="px-4 py-3"><%= attachee.user.username %></td>
                      <td class="px-4 py-3"><%= attachee.organization.name %></td>
                      <td class="px-4 py-3"><%= attachee.department.name %></td>
                      <td class="px-4 py-3">
                        <%= if Ecto.assoc_loaded?(attachee.programs) and attachee.programs != [] do %>
                          <%= Enum.map_join(attachee.programs, ", ", fn program ->
                            program.name
                          end) %>
                        <% else %>
                          N/A
                        <% end %>
                      </td>
                      <td class="px-4 py-3"><%= attachee.status %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end

  # Toggle form visibility
  def handle_event("toggle_form", _params, socket) do
    # Reset form when toggling
    changeset = Attachee.changeset(%Attachee{}, %{})
    {:noreply,
     socket
     |> assign(:show_form, !socket.assigns.show_form)
     |> assign(:form, to_form(changeset))
     |> assign(:departments, [])
     |> assign(:programs, [])}
  end

  # Handle updates for dependent dropdowns
  def handle_event("update", %{"attachee" => params}, socket) do
    org_id = safe_int(Map.get(params, "organization_id"))
    dept_id = safe_int(Map.get(params, "department_id"))

    departments = if org_id, do: Orgs.list_departments_by_org(org_id), else: socket.assigns.departments
    programs = if dept_id, do: Eams.list_programs_by_department(dept_id), else: socket.assigns.programs

    # Get current form params and merge with new params
    current_params = socket.assigns.form.params
    merged_params = Map.merge(current_params, params)

    # Update changeset with merged params
    changeset =
      %Attachee{}
      |> Attachee.changeset(merged_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  # Save new attachee
  def handle_event("save", %{"attachee" => params}, socket) do
    # Convert string IDs to integers and parse dates
    attrs = %{
      user_id: safe_int(params["user_id"]),
      organization_id: safe_int(params["organization_id"]),
      department_id: safe_int(params["department_id"]),
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: "active"
    }

    program_id = safe_int(params["program_id"])

    case Eams.create_attachee(attrs) do
      {:ok, attachee} ->
        # Enroll in program (if selected)
        if program_id do
          Eams.enroll_attachee_in_program(attachee.id, program_id)
        end

        # Reload attachees list
        updated_attachees =
          Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})

        # Reset form
        changeset = Attachee.changeset(%Attachee{}, %{})

        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form, to_form(changeset))
         |> assign(:attachees, updated_attachees)
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> put_flash(:info, "Attachee created successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Failed to create attachee. Please check the errors.")}
    end
  end

  # Helpers
  defp safe_int(value) when is_binary(value) and value != "", do: String.to_integer(value)
  defp safe_int(_), do: nil

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(_), do: nil

  defp translate_errors(errors) do
    Enum.map_join(errors, ", ", fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
