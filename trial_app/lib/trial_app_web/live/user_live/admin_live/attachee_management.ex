defmodule TrialAppWeb.AdminLive.AttacheeManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs, Accounts}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:attachees, Eams.list_attachees())
     |> assign(:show_form, false)
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:users, Accounts.list_users())
     |> assign(:form_data, %{"user_id" => "", "organization_id" => "", "department_id" => "", "program_id" => "", "status" => "active", "starts_on" => "", "ends_on" => ""})
     |> assign(:errors, %{})}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />
    <div class="ml-64 p-8">
      <h1 class="text-2xl font-bold mb-4">Attachees</h1>
      <div class="flex justify-end mb-3">
        <button phx-click="new" class="px-4 py-2 rounded-lg bg-indigo-600 text-white">New Attachee</button>
      </div>
      <div class="bg-white rounded-xl border p-4">
        <%= if @attachees == [] do %>
          <p class="text-gray-600">No attachees yet.</p>
        <% else %>
          <ul class="space-y-2">
            <%= for a <- @attachees do %>
              <li class="border rounded-lg p-3">
                <div class="font-semibold">{a.user_id}</div>
                <div class="text-sm text-gray-500">Status: {a.status}</div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4">
          <div class="bg-white rounded-xl w-full max-w-lg p-6">
            <h2 class="text-xl font-bold mb-4">Create Attachee</h2>
            <.form for={to_form(@form_data, as: :attachee)} id="attachee-form" phx-submit="save" phx-change="update">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium">User</label>
                  <select name="user_id" class="w-full border rounded p-2" required>
                    <option value="">Select user</option>
                    <%= for u <- @users do %>
                      <option value={u.id} selected={to_string(u.id) == @form_data["user_id"]}>{u.username || u.email}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium">Organization</label>
                  <select name="organization_id" class="w-full border rounded p-2" required>
                    <option value="">Select organization</option>
                    <%= for o <- @orgs do %>
                      <option value={o.id} selected={to_string(o.id) == @form_data["organization_id"]}>{o.name}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium">Department</label>
                  <select name="department_id" class="w-full border rounded p-2" required>
                    <option value="">Select department</option>
                    <%= for d <- @departments do %>
                      <option value={d.id} selected={to_string(d.id) == @form_data["department_id"]}>{d.name}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium">Enroll to Program (optional)</label>
                  <select name="program_id" class="w-full border rounded p-2">
                    <option value="">Select program</option>
                    <%= for p <- @programs do %>
                      <option value={p.id} selected={to_string(p.id) == @form_data["program_id"]}>{p.name}</option>
                    <% end %>
                  </select>
                </div>
                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium">Start date</label>
                    <input type="date" name="starts_on" value={@form_data["starts_on"]} class="w-full border rounded p-2" />
                  </div>
                  <div>
                    <label class="block text-sm font-medium">End date</label>
                    <input type="date" name="ends_on" value={@form_data["ends_on"]} class="w-full border rounded p-2" />
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium">Status</label>
                  <select name="status" class="w-full border rounded p-2">
                    <%= for s <- ["active","suspended","completed"] do %>
                      <option value={s} selected={s == @form_data["status"]}>{s}</option>
                    <% end %>
                  </select>
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

  def handle_event("update", %{"attachee" => params}, socket) do
    org_id = Map.get(params, "organization_id")
    dept_id = Map.get(params, "department_id")
    org_int = safe_int(org_id)
    dept_int = safe_int(dept_id)
    departments = if is_integer(org_int), do: Orgs.list_departments_by_org(org_int), else: []
    programs = if is_integer(dept_int), do: Eams.list_programs_by_department(dept_int), else: []

    {:noreply,
     socket
     |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  def handle_event("save", %{"attachee" => params}, socket) do
    attrs = %{
      user_id: parse_int(params["user_id"]),
      organization_id: parse_int(params["organization_id"]),
      department_id: parse_int(params["department_id"]),
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: params["status"]
    }

    case Eams.create_attachee(attrs) do
      {:ok, attachee} ->
        _ =
          case parse_int(params["program_id"]) do
            nil -> {:ok, :skip}
            program_id -> Eams.enroll_attachee_in_program(attachee.id, program_id)
          end

        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form_data, %{"user_id" => "", "organization_id" => "", "department_id" => "", "program_id" => "", "status" => "active", "starts_on" => "", "ends_on" => ""})
         |> assign(:attachees, Eams.list_attachees())}

      {:error, changeset} ->
        {:noreply, assign(socket, errors: changeset.errors |> Enum.into(%{}))}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    {:ok, date} = Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d))
    date
  end
  defp safe_int(nil), do: nil
  defp safe_int(""), do: nil
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end
end
