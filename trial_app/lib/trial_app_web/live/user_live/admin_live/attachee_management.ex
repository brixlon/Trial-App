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
       show_modal: false,
       editing_attachee: nil,
       filter_status: "all"
     )}
  end

  # View attachee details - Navigate to show page
  def handle_event("view_attachee", %{"id" => id}, socket) do
    # Navigate to the standalone attachee management show page
    {:noreply, push_navigate(socket, to: ~p"/admin/eams/attachees/manage/#{id}")}
  end

  # ... rest of the code remains the same ...
  # (All other handle_event functions, render, and helpers stay unchanged)

  # Open modal for new attachee
  def handle_event("open_modal", _params, socket) do
    changeset = Attachee.changeset(%Attachee{}, %{})
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_attachee, nil)
     |> assign(:form, to_form(changeset))
     |> assign(:departments, [])
     |> assign(:programs, [])}
  end

  # Close modal
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  # Prevent modal from closing when clicking inside
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  # Handle filter
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  # Edit attachee
  def handle_event("edit_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id) |> Repo.preload([:user, :organization, :department, :programs])

    # Load departments for the organization
    departments = if attachee.organization_id do
      Orgs.list_departments_by_org(attachee.organization_id)
    else
      []
    end

    # Load programs for the department
    programs = if attachee.department_id do
      Eams.list_programs_by_department(attachee.department_id)
    else
      []
    end

    # Get the first program ID if any programs are enrolled
    program_id = if Ecto.assoc_loaded?(attachee.programs) and attachee.programs != [] do
      hd(attachee.programs).id
    else
      nil
    end

    # Create changeset with current attachee data
    changeset = Attachee.changeset(attachee, %{
      "program_id" => program_id
    })

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_attachee, attachee)
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  # Delete attachee
  def handle_event("delete_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id)

    case Eams.delete_attachee(attachee) do
      {:ok, _} ->
        updated_attachees = Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})
        {:noreply,
         socket
         |> assign(:attachees, updated_attachees)
         |> put_flash(:info, "Attachee deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete attachee")}
    end
  end

  # Validate form on change
  def handle_event("validate", %{"attachee" => params}, socket) do
    attachee = socket.assigns.editing_attachee || %Attachee{}

    changeset =
      attachee
      |> Attachee.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # Handle organization selection change
  def handle_event("organization_changed", %{"attachee" => params}, socket) do
    org_id = safe_int(params["organization_id"])

    departments = if org_id do
      Orgs.list_departments_by_org(org_id)
    else
      []
    end

    # Reset department and program when organization changes
    params = params
      |> Map.put("department_id", "")
      |> Map.put("program_id", "")

    attachee = socket.assigns.editing_attachee || %Attachee{}
    changeset =
      attachee
      |> Attachee.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, [])}
  end

  # Handle department selection change
  def handle_event("department_changed", %{"attachee" => params}, socket) do
    dept_id = safe_int(params["department_id"])

    programs = if dept_id do
      Eams.list_programs_by_department(dept_id)
    else
      []
    end

    # Reset program when department changes
    params = Map.put(params, "program_id", "")

    attachee = socket.assigns.editing_attachee || %Attachee{}
    changeset =
      attachee
      |> Attachee.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:programs, programs)}
  end

  # Save new or update attachee
  def handle_event("save", %{"attachee" => params}, socket) do
    # Convert string IDs to integers and parse dates
    attrs = %{
      user_id: safe_int(params["user_id"]),
      organization_id: safe_int(params["organization_id"]),
      department_id: safe_int(params["department_id"]),
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: params["status"] || "active"
    }

    program_id = safe_int(params["program_id"])

    result = if socket.assigns.editing_attachee do
      Eams.update_attachee(socket.assigns.editing_attachee, attrs)
    else
      Eams.create_attachee(attrs)
    end

    case result do
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
         |> assign(:show_modal, false)
         |> assign(:editing_attachee, nil)
         |> assign(:form, to_form(changeset))
         |> assign(:attachees, updated_attachees)
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> put_flash(:info, "Attachee #{if socket.assigns.editing_attachee, do: "updated", else: "created"} successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Failed to save attachee. Please check the errors.")}
    end
  end

  # Helpers
  defp safe_int(value) when is_binary(value) and value != "", do: String.to_integer(value)
  defp safe_int(value) when is_integer(value), do: value
  defp safe_int(_), do: nil

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(%Date{} = date), do: date
  defp parse_date(_), do: nil

  defp user_display(user), do: "#{user.username} (#{user.email})"

  defp department_options([]), do: [{"Select organization first", ""}]
  defp department_options(departments) do
    [{"Select Department", ""} | Enum.map(departments, &{&1.name, &1.id})]
  end

  defp program_options([]), do: [{"Select department first", ""}]
  defp program_options(programs) do
    [{"Select Program (Optional)", ""} | Enum.map(programs, &{&1.name, &1.id})]
  end

  defp status_color("active"), do: "bg-green-100 text-green-800"
  defp status_color("inactive"), do: "bg-amber-100 text-amber-800"
  defp status_color("completed"), do: "bg-blue-100 text-blue-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp filtered_attachees(attachees, "all"), do: attachees
  defp filtered_attachees(attachees, status), do: Enum.filter(attachees, &(&1.status == status))

  defp count_by_status(attachees, "all"), do: length(attachees)
  defp count_by_status(attachees, status), do: Enum.count(attachees, &(&1.status == status))

  # Render template - SAME AS ORIGINAL
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">

        <!-- Main content -->
        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-8">
            <!-- Header -->
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-semibold text-gray-800">Attachee Management</h1>
                <p class="text-sm text-gray-500 mt-1">Manage attachees and their enrollments</p>
              </div>
              <button
                phx-click="open_modal"
                class="bg-purple-600 text-white px-4 py-2 rounded-lg shadow hover:bg-purple-700 transition"
              >
                Add Attachee
              </button>
            </div>

            <!-- Filter Tabs -->
            <div class="flex gap-2 border-b border-gray-200">
              <%= for {label, status} <- [
                    {"All", "all"},
                    {"Active", "active"},
                    {"Inactive", "inactive"},
                    {"Completed", "completed"}
                  ] do %>
                <button
                  phx-click="filter"
                  phx-value-status={status}
                  class={"px-4 py-2 text-sm font-medium border-b-2 transition #{if @filter_status == status, do: "border-purple-600 text-purple-600", else: "border-transparent text-gray-500 hover:text-gray-700"}"}
                >
                  <%= label %>
                  <span class="ml-1 text-xs bg-gray-100 px-2 py-0.5 rounded-full">
                    <%= count_by_status(@attachees, status) %>
                  </span>
                </button>
              <% end %>
            </div>

            <!-- Stats Summary -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div class="bg-purple-50 p-4 rounded-lg border border-purple-100">
                <div class="text-sm text-purple-600 font-medium">Total</div>
                <div class="text-2xl font-bold text-purple-700 mt-1"><%= length(@attachees) %></div>
              </div>
              <div class="bg-green-50 p-4 rounded-lg border border-green-100">
                <div class="text-sm text-green-600 font-medium">Active</div>
                <div class="text-2xl font-bold text-green-700 mt-1">
                  <%= Enum.count(@attachees, &(&1.status == "active")) %>
                </div>
              </div>
              <div class="bg-amber-50 p-4 rounded-lg border border-amber-100">
                <div class="text-sm text-amber-600 font-medium">Inactive</div>
                <div class="text-2xl font-bold text-amber-700 mt-1">
                  <%= Enum.count(@attachees, &(&1.status == "inactive")) %>
                </div>
              </div>
              <div class="bg-blue-50 p-4 rounded-lg border border-blue-100">
                <div class="text-sm text-blue-600 font-medium">Completed</div>
                <div class="text-2xl font-bold text-blue-700 mt-1">
                  <%= Enum.count(@attachees, &(&1.status == "completed")) %>
                </div>
              </div>
            </div>

            <!-- Attachee List -->
            <div class="bg-white shadow rounded-xl overflow-hidden">
              <%= if filtered_attachees(@attachees, @filter_status) == [] do %>
                <div class="py-12 text-center">
                  <p class="text-gray-500 text-lg mb-2">No attachees found</p>
                  <p class="text-sm text-gray-400">
                    <%= if @filter_status == "all" do %>
                      Get started by adding your first attachee
                    <% else %>
                      Try changing the filter or add a new attachee
                    <% end %>
                  </p>
                </div>
              <% else %>
                <table class="min-w-full text-sm text-left text-gray-700">
                  <thead class="bg-gray-100 text-xs uppercase">
                    <tr>
                      <th class="px-4 py-3">User</th>
                      <th class="px-4 py-3">Organization</th>
                      <th class="px-4 py-3">Department</th>
                      <th class="px-4 py-3">Program(s)</th>
                      <th class="px-4 py-3">Duration</th>
                      <th class="px-4 py-3">Status</th>
                      <th class="px-4 py-3 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for attachee <- filtered_attachees(@attachees, @filter_status) do %>
                      <tr
                        class="border-t hover:bg-gray-50 transition cursor-pointer"
                        phx-click="view_attachee"
                        phx-value-id={attachee.id}
                      >
                        <td class="px-4 py-3">
                          <div class="font-medium text-gray-900"><%= attachee.user.username %></div>
                          <div class="text-xs text-gray-500"><%= attachee.user.email %></div>
                        </td>
                        <td class="px-4 py-3"><%= attachee.organization.name %></td>
                        <td class="px-4 py-3">
                          <span class="inline-flex items-center px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800">
                            <%= attachee.department.name %>
                          </span>
                        </td>
                        <td class="px-4 py-3">
                          <%= if Ecto.assoc_loaded?(attachee.programs) and attachee.programs != [] do %>
                            <div class="flex flex-wrap gap-1">
                              <%= for program <- Enum.take(attachee.programs, 2) do %>
                                <span class="inline-flex items-center px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                                  <%= program.name %>
                                </span>
                              <% end %>
                              <%= if length(attachee.programs) > 2 do %>
                                <span class="inline-flex items-center px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-600">
                                  +<%= length(attachee.programs) - 2 %>
                                </span>
                              <% end %>
                            </div>
                          <% else %>
                            <span class="text-gray-400">N/A</span>
                          <% end %>
                        </td>
                        <td class="px-4 py-3">
                          <%= if attachee.starts_on do %>
                            <div class="text-sm">
                              <%= Calendar.strftime(attachee.starts_on, "%b %d, %Y") %>
                              <%= if attachee.ends_on do %>
                                <div class="text-xs text-gray-500">
                                  to <%= Calendar.strftime(attachee.ends_on, "%b %d, %Y") %>
                                </div>
                              <% end %>
                            </div>
                          <% else %>
                            <span class="text-gray-400">Not set</span>
                          <% end %>
                        </td>
                        <td class="px-4 py-3">
                          <span class={"inline-flex items-center px-2 py-1 text-xs rounded-full font-medium #{status_color(attachee.status)}"}>
                            <%= String.capitalize(attachee.status) %>
                          </span>
                        </td>
                        <td class="px-4 py-3" phx-click="stop_propagation">
                          <div class="flex items-center justify-end gap-2">
                            <button
                              phx-click="edit_attachee"
                              phx-value-id={attachee.id}
                              class="p-1.5 hover:bg-purple-50 rounded text-purple-600"
                              title="Edit"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                              </svg>
                            </button>
                            <button
                              phx-click="delete_attachee"
                              phx-value-id={attachee.id}
                              data-confirm="Are you sure you want to delete this attachee?"
                              class="p-1.5 hover:bg-red-50 rounded text-red-600"
                              title="Delete"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              <% end %>
            </div>
          </div>
        </main>
      </div>

      <!-- Modal (unchanged) -->
      <%= if @show_modal do %>
        <div class="fixed inset-0 z-50 overflow-y-auto" phx-click="close_modal">
          <div class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div
              class="relative bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto"
              phx-click="stop_propagation"
            >
              <div class="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between rounded-t-xl">
                <h2 class="text-xl font-semibold text-gray-800">
                  <%= if @editing_attachee, do: "Edit Attachee", else: "Add New Attachee" %>
                </h2>
                <button
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-gray-600 transition"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <div class="px-6 py-4">
                <.form for={@form} phx-submit="save" phx-change="validate">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <.input
                        field={@form[:user_id]}
                        type="select"
                        label="User"
                        options={[{"Select User", ""} | Enum.map(@users, &{user_display(&1), &1.id})]}
                        required
                      />
                    </div>

                    <div>
                      <.input
                        field={@form[:organization_id]}
                        type="select"
                        label="Organization"
                        options={[{"Select Organization", ""} | Enum.map(@organizations, &{&1.name, &1.id})]}
                        phx-change="organization_changed"
                        required
                      />
                    </div>

                    <div>
                      <.input
                        field={@form[:department_id]}
                        type="select"
                        label="Department"
                        options={department_options(@departments)}
                        phx-change="department_changed"
                        required
                      />
                    </div>

                    <div>
                      <.input
                        field={@form[:program_id]}
                        type="select"
                        label="Program"
                        options={program_options(@programs)}
                      />
                    </div>

                    <div>
                      <.input
                        field={@form[:starts_on]}
                        type="date"
                        label="Start Date"
                        required
                      />
                    </div>

                    <div>
                      <.input
                        field={@form[:ends_on]}
                        type="date"
                        label="End Date"
                      />
                    </div>

                    <%= if @editing_attachee do %>
                      <div>
                        <.input
                          field={@form[:status]}
                          type="select"
                          label="Status"
                          options={[
                            {"Active", "active"},
                            {"Inactive", "inactive"},
                            {"Completed", "completed"}
                          ]}
                        />
                      </div>
                    <% end %>
                  </div>

                  <div class="mt-6 flex justify-end gap-3">
                    <button
                      type="button"
                      phx-click="close_modal"
                      class="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="bg-green-600 text-white px-4 py-2 rounded-lg shadow hover:bg-green-700 transition"
                    >
                      <%= if @editing_attachee, do: "Update Attachee", else: "Save Attachee" %>
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
