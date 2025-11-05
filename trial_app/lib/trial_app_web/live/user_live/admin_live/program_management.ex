defmodule TrialAppWeb.AdminLive.ProgramManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}

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
     |> assign(:form_data, %{"name" => "", "description" => "", "organization_id" => "", "department_id" => "", "code" => "", "starts_on" => "", "ends_on" => "", "status" => "active"})
     |> assign(:errors, %{})}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

<div class="ml-64 p-8">
  <h1 class="text-2xl font-bold mb-4">Programs</h1>

  <!-- New Program Button -->
  <div class="flex justify-end mb-3">
    <button phx-click="new" class="px-4 py-2 rounded-lg bg-indigo-600 text-white">New Program</button>
  </div>

  <!-- Attachee Filter -->
  <div class="mt-8 bg-white rounded-xl border p-4">
    <h2 class="text-lg font-semibold mb-3">Attachees in Department and Program</h2>
    <.form for={to_form(%{}, as: :filter)} id="attachee-filter" phx-change="filter_update">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div>
          <label class="block text-sm font-medium">Organization</label>
          <select name="organization_id" class="w-full border rounded p-2">
            <option value="">Select organization</option>
            <%= for o <- @orgs do %>
              <option value={o.id} selected={to_string(o.id) == @filter_org_id}>{o.name}</option>
            <% end %>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium">Department</label>
          <select name="department_id" class="w-full border rounded p-2">
            <option value="">Select department</option>
            <%= for d <- @filter_departments do %>
              <option value={d.id} selected={to_string(d.id) == @filter_department_id}>{d.name}</option>
            <% end %>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium">Program</label>
          <select name="program_id" class="w-full border rounded p-2">
            <option value="">Select program</option>
            <%= for p <- @filter_programs do %>
              <option value={p.id} selected={to_string(p.id) == @filter_program_id}>{p.name}</option>
            <% end %>
          </select>
        </div>
      </div>
    </.form>

    <div class="mt-4">
      <%= if @filtered_attachees == [] do %>
        <p class="text-gray-600">No attachees for the selected filters.</p>
      <% else %>
        <div class="overflow-hidden rounded border">
          <table class="min-w-full divide-y">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600">Full Name</th>
                <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600">Email</th>
                <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600">Position</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y">
              <%= for a <- @filtered_attachees do %>
                <tr>
                  <td class="px-4 py-2 text-sm">{a.user && (a.user.username || a.user.email) || ("Attachee " <> to_string(a.id))}</td>
                  <td class="px-4 py-2 text-sm">{a.user && a.user.email || "-"}</td>
                  <td class="px-4 py-2 text-sm">Attachee</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Programs List -->
  <div class="bg-white rounded-xl border p-4 mt-6">
    <%= if @programs == [] do %>
      <p class="text-gray-600">No programs yet.</p>
    <% else %>
      <ul class="space-y-2">
        <%= for prog <- @programs do %>
          <li class="border rounded-lg p-3">
            <div class="font-semibold">{prog.name}</div>
            <div class="text-sm text-gray-500">{prog.code}</div>
          </li>
        <% end %>
      </ul>
    <% end %>
  </div>

  <!-- New Program Modal -->
  <%= if @show_form do %>
    <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4">
      <div class="bg-white rounded-xl w-full max-w-lg p-6">
        <h2 class="text-xl font-bold mb-4">Create Program</h2>
        <.form for={to_form(@form_data, as: :program)} id="program-form" phx-submit="save" phx-change="update">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium">Name</label>
              <input name="program[name]" value={@form_data["name"]} class="w-full border rounded p-2" required />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-medium">Start date</label>
                <input type="date" name="program[starts_on]" value={@form_data["starts_on"]} class="w-full border rounded p-2" />
              </div>
              <div>
                <label class="block text-sm font-medium">End date</label>
                <input type="date" name="program[ends_on]" value={@form_data["ends_on"]} class="w-full border rounded p-2" />
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium">Code</label>
              <input name="program[code]" value={@form_data["code"]} class="w-full border rounded p-2" />
            </div>

            <div>
              <label class="block text-sm font-medium">Organization</label>
              <select name="program[organization_id]" class="w-full border rounded p-2" required>
                <option value="">Select organization</option>
                <%= for o <- @orgs do %>
                  <option value={o.id} selected={to_string(o.id) == @form_data["organization_id"]}>{o.name}</option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium">Department</label>
              <select name="program[department_id]" class="w-full border rounded p-2" required>
                <option value="">Select department</option>
                <%= for d <- @departments do %>
                  <option value={d.id} selected={to_string(d.id) == @form_data["department_id"]}>{d.name}</option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium">Description</label>
              <textarea name="program[description]" class="w-full border rounded p-2" rows="3"><%= @form_data["description"] %></textarea>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close" class="px-4 py-2 rounded border">Cancel</button>
            <button type="submit" class="px-4 py-2 rounded bg-indigo-600 text-white">Save</button>
          </div>
        </.form>
      </div>
    </div>
  <% end %>
</div>

    """
  end

  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  def handle_event("update", %{"program" => params}, socket) do
  org_id = Map.get(params, "organization_id")
  org_int = safe_int(org_id)
  departments = if is_integer(org_int), do: Orgs.list_departments_by_org(org_int), else: []

  {:noreply,
   socket
   |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
   |> assign(:departments, departments)
   |> assign(:show_form, true)}  # <- keep modal open
end



 def handle_event("save", %{"program" => params}, socket) do
  attrs = %{
    name: params["name"],
    description: params["description"],
    code: params["code"],
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
       |> assign(:form_data, %{
         "name" => "",
         "description" => "",
         "organization_id" => "",
         "department_id" => "",
         "code" => "",
         "starts_on" => "",
         "ends_on" => "",
         "status" => "active"
       })
       |> assign(:departments, [])  # clear department dropdown
       |> assign(:programs, Eams.list_programs())
       |> put_flash(:info, "Program created successfully!")}

    {:error, changeset} ->
      {:noreply,
       socket
       |> assign(:errors, Enum.into(changeset.errors, %{}))
       |> put_flash(:error, "Failed to create program. Check inputs.")}
  end
end


  def handle_event("filter_update", %{
      "organization_id" => org_id,
      "department_id" => dept_id,
      "program_id" => prog_id
    } = _params, socket) do

  filter_departments =
    case org_id do
      nil -> []
      "" -> []
      id -> Orgs.list_departments_by_org(String.to_integer(id))
    end

  filter_programs =
    case dept_id do
      nil -> []
      "" -> []
      id -> Eams.list_programs_by_department(String.to_integer(id))
    end

  filtered_attachees =
    case prog_id do
      nil -> []
      "" -> []
      id -> Eams.list_attachees_by_program(String.to_integer(id), %{preloads: [:user]})
    end

  {:noreply,
   socket
   |> assign(:filter_org_id, org_id || "")
   |> assign(:filter_department_id, dept_id || "")
   |> assign(:filter_program_id, prog_id || "")
   |> assign(:filter_departments, filter_departments)
   |> assign(:filter_programs, filter_programs)
   |> assign(:filtered_attachees, filtered_attachees)}
end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(nil), do: nil
  defp safe_int(""), do: nil
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    {:ok, date} = Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d))
    date
  end
end
