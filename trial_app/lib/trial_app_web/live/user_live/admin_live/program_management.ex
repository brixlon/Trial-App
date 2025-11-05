defmodule TrialAppWeb.AdminLive.ProgramManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:programs, Eams.list_programs())
     |> assign(:show_form, false)
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:filter_departments, [])
     |> assign(:filter_programs, [])
     |> assign(:filtered_attachees, [])
     |> assign(:filter_org_id, "")
     |> assign(:filter_department_id, "")
     |> assign(:filter_program_id, "")
     |> assign(:form_data, %{
       "name" => "", "description" => "", "organization_id" => "",
       "department_id" => "", "code" => "", "starts_on" => "", "ends_on" => "", "status" => "active"
     })
     |> assign(:errors, %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />
    <div class="ml-64 p-8">
      <h1 class="text-2xl font-bold mb-4">Programs</h1>
      <div class="flex justify-end mb-3">
        <button phx-click="new" class="px-4 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 transition">
          New Program
        </button>
      </div>

      <!-- Attachee Filter Section -->
      <div class="mt-8 bg-white rounded-xl border p-4">
        <h2 class="text-lg font-semibold mb-3">Attachees in Department and Program</h2>

        <!-- Fixed: Use plain <form> with phx-change, no <.form> -->
        <form id="attachee-filter" phx-change="filter_update">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div>
              <label class="block text-sm font-medium text-gray-700">Organization</label>
              <select name="organization_id" class="mt-1 block w-full border rounded-md p-2 text-sm">
                <option value="">Select organization</option>
                <%= for o <- @orgs do %>
                  <option value={o.id} selected={to_string(o.id) == @filter_org_id}><%= o.name %></option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Department</label>
              <select name="department_id" class="mt-1 block w-full border rounded-md p-2 text-sm">
                <option value="">Select department</option>
                <%= for d <- @filter_departments do %>
                  <option value={d.id} selected={to_string(d.id) == @filter_department_id}><%= d.name %></option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Program</label>
              <select name="program_id" class="mt-1 block w-full border rounded-md p-2 text-sm">
                <option value="">Select program</option>
                <%= for p <- @filter_programs do %>
                  <option value={p.id} selected={to_string(p.id) == @filter_program_id}><%= p.name %></option>
                <% end %>
              </select>
            </div>
          </div>
        </form>

        <div class="mt-4">
          <%= if Enum.empty?(@filtered_attachees) do %>
            <p class="text-gray-600 text-sm">No attachees for the selected filters.</p>
          <% else %>
            <div class="overflow-hidden rounded-lg border border-gray-200">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Full Name</th>
                    <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Email</th>
                    <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Position</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for a <- @filtered_attachees do %>
                    <tr>
                      <td class="px-4 py-2 text-sm text-gray-900">
                        <%= if a.user do %>
                          <%= a.user.username || a.user.email %>
                        <% else %>
                          Attachee <%= a.id %>
                        <% end %>
                      </td>
                      <td class="px-4 py-2 text-sm text-gray-600"><%= a.user && a.user.email || "-" %></td>
                      <td class="px-4 py-2 text-sm text-gray-600">Attachee</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Programs List -->
      <div class="mt-6 bg-white rounded-xl border p-4">
        <%= if Enum.empty?(@programs) do %>
          <p class="text-gray-600 text-sm">No programs yet.</p>
        <% else %>
          <ul class="space-y-3">
            <%= for prog <- @programs do %>
              <li class="border rounded-lg p-4 bg-gray-50 hover:bg-gray-100 transition">
                <div class="font-semibold text-gray-900"><%= prog.name %></div>
                <div class="text-sm text-gray-500"><%= prog.code %></div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <!-- Create Program Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-xl w-full max-w-lg p-6 shadow-xl">
            <h2 class="text-xl font-bold mb-4 text-gray-900">Create Program</h2>

            <!-- Keep <.form> here because we need changeset validation -->
            <.form for={:program} id="program-form" phx-submit="save" phx-change="update_form">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Name <span class="text-red-500">*</span></label>
                  <input
                    type="text"
                    name="name"
                    value={@form_data["name"]}
                    class="mt-1 block w-full border rounded-md p-2 text-sm"
                    required
                  />
                  <%= if error = @errors[:name] do %>
                    <p class="mt-1 text-xs text-red-600"><%= error %></p>
                  <% end %>
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Start date</label>
                    <input
                      type="date"
                      name="starts_on"
                      value={@form_data["starts_on"]}
                      class="mt-1 block w-full border rounded-md p-2 text-sm"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">End date</label>
                    <input
                      type="date"
                      name="ends_on"
                      value={@form_data["ends_on"]}
                      class="mt-1 block w-full border rounded-md p-2 text-sm"
                    />
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Code</label>
                  <input
                    type="text"
                    name="code"
                    value={@form_data["code"]}
                    class="mt-1 block w-full border rounded-md p-2 text-sm"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Organization <span class="text-red-500">*</span></label>
                  <select name="organization_id" class="mt-1 block w-full border rounded-md p-2 text-sm" required>
                    <option value="">Select organization</option>
                    <%= for o <- @orgs do %>
                      <option value={o.id} selected={to_string(o.id) == @form_data["organization_id"]}>
                        <%= o.name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Department <span class="text-red-500">*</span></label>
                  <select name="department_id" class="mt-1 block w-full border rounded-md p-2 text-sm" required>
                    <option value="">Select department</option>
                    <%= for d <- @departments do %>
                      <option value={d.id} selected={to_string(d.id) == @form_data["department_id"]}>
                        <%= d.name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Description</label>
                  <textarea
                    name="description"
                    rows="3"
                    class="mt-1 block w-full border rounded-md p-2 text-sm"
                  ><%= @form_data["description"] %></textarea>
                </div>
              </div>

              <div class="flex justify-end gap-2 mt-6">
                <button
                  type="button"
                  phx-click="close"
                  class="px-4 py-2 rounded border border-gray-300 text-gray-700 hover:bg-gray-50 transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700 transition"
                >
                  Save
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # === Event Handlers ===

  @impl true
  def handle_event("new", _, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply,
     socket
     |> assign(show_form: false)
     |> assign(errors: %{})
     |> assign(form_data: %{
       "name" => "", "description" => "", "organization_id" => "",
       "department_id" => "", "code" => "", "starts_on" => "", "ends_on" => "", "status" => "active"
     })}
  end

  @impl true
  def handle_event("update_form", %{"program" => params}, socket) do
    org_id = params["organization_id"] || ""
    org_int = safe_int(org_id)
    departments = if org_int, do: Orgs.list_departments_by_org(org_int), else: []

  {:noreply,
   socket
   |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
   |> assign(:departments, departments)
   |> assign(:show_form, true)}  # <- keep modal open
end



  @impl true
  def handle_event("save", %{"program" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"] || "",
      code: params["code"] || "",
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: "active",
      organization_id: parse_int(params["organization_id"]),
      department_id: parse_int(params["department_id"])
    }

    case Eams.create_program(attrs) do
      {:ok, _program} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:errors, %{})
         |> assign(:form_data, %{
           "name" => "", "description" => "", "organization_id" => "",
           "department_id" => "", "code" => "", "starts_on" => "", "ends_on" => "", "status" => "active"
         })
         |> assign(:programs, Eams.list_programs())}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = changeset.errors |> Enum.map(fn {field, {msg, _}} -> {field, msg} end) |> Enum.into(%{})
        {:noreply, assign(socket, :errors, errors)}
    end
  end

  @impl true
  def handle_event("filter_update", params, socket) do
    org_id = Map.get(params, "organization_id", "")
    dept_id = Map.get(params, "department_id", "")
    prog_id = Map.get(params, "program_id", "")

    filter_departments = load_departments(org_id)
    filter_programs = load_programs(dept_id)
    filtered_attachees = load_attachees(prog_id)

    {:noreply,
     socket
     |> assign(:filter_departments, filter_departments)
     |> assign(:filter_programs, filter_programs)
     |> assign(:filtered_attachees, filtered_attachees)
     |> assign(:filter_org_id, org_id)
     |> assign(:filter_department_id, dept_id)
     |> assign(:filter_program_id, prog_id)}
  end

  # === Helper Functions ===

  defp load_departments(""), do: []
  defp load_departments(nil), do: []
  defp load_departments(id), do: Orgs.list_departments_by_org(String.to_integer(id))

  defp load_programs(""), do: []
  defp load_programs(nil), do: []
  defp load_programs(id), do: Eams.list_programs_by_department(String.to_integer(id))

  defp load_attachees(""), do: []
  defp load_attachees(nil), do: []
  defp load_attachees(id), do: Eams.list_attachees_by_program(String.to_integer(id), %{preloads: [:user]})

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(""), do: nil
  defp safe_int(nil), do: nil
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(<<y::4-binary, "-", m::2-binary, "-", d::2-binary>>) do
    with {year, _} <- Integer.parse(y),
         {month, _} <- Integer.parse(m),
         {day, _} <- Integer.parse(d),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _ -> nil
    end
  end
  defp parse_date(_), do: nil
end
