defmodule TrialAppWeb.AdminLive.ProjectManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}
  alias TrialApp.Accounts

  # =========================
  # Mount
  # =========================
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:projects, Eams.list_projects())
     |> assign(:show_form, false)
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:supervisors, Accounts.list_users_by_role("admin") ++ Accounts.list_users_by_role("manager"))
     |> assign(:form_data, empty_form())
     |> assign(:errors, %{})}
  end

  # =========================
  # Render
  # =========================
  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

    <div class="ml-64 p-8">
      <h1 class="text-2xl font-bold mb-4">Projects</h1>

      <div class="flex justify-end mb-3">
        <button phx-click="new" class="px-4 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700">
          + New Project
        </button>
      </div>

      <div class="bg-white rounded-xl border p-4">
        <%= if @projects == [] do %>
          <p class="text-gray-600">No projects yet.</p>
        <% else %>
          <ul class="space-y-2">
            <%= for project <- @projects do %>
              <li class="border rounded-lg p-3">
                <div class="font-semibold"><%= project.name %></div>
                <div class="text-sm text-gray-500"><%= project.code %></div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <!-- ========== FORM MODAL ========== -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-xl w-full max-w-lg p-6 shadow-xl">
            <h2 class="text-xl font-bold mb-4">Create Project</h2>

            <.form for={to_form(@form_data, as: :project)} id="project-form" phx-submit="save" phx-change="update">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium">Name</label>
                  <input name="project[name]" value={@form_data["name"]} class="w-full border rounded p-2" required />
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium">Start date</label>
                    <input type="date" name="project[starts_on]" value={@form_data["starts_on"]} class="w-full border rounded p-2" />
                  </div>
                  <div>
                    <label class="block text-sm font-medium">End date</label>
                    <input type="date" name="project[ends_on]" value={@form_data["ends_on"]} class="w-full border rounded p-2" />
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium">Code</label>
                  <input name="project[code]" value={@form_data["code"]} class="w-full border rounded p-2" />
                </div>

                <div>
                  <label class="block text-sm font-medium">Supervisor</label>
                  <select name="project[supervisor_id]" class="w-full border rounded p-2" required>
                    <option value="">Select supervisor</option>
                    <%= for s <- @supervisors do %>
                      <option value={s.id} selected={to_string(s.id) == @form_data["supervisor_id"]}>
                        <%= s.username || s.email %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium">Organization</label>
                  <select name="project[organization_id]" class="w-full border rounded p-2" required>
                    <option value="">Select organization</option>
                    <%= for o <- @orgs do %>
                      <option value={o.id} selected={to_string(o.id) == @form_data["organization_id"]}>
                        <%= o.name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium">Department</label>
                  <select name="project[department_id]" class="w-full border rounded p-2" required>
                    <option value="">Select department</option>
                    <%= for d <- @departments do %>
                      <option value={d.id} selected={to_string(d.id) == @form_data["department_id"]}>
                        <%= d.name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium">Program</label>
                  <select name="project[program_id]" class="w-full border rounded p-2" required>
                    <option value="">Select program</option>
                    <%= for p <- @programs do %>
                      <option value={p.id} selected={to_string(p.id) == @form_data["program_id"]}>
                        <%= p.name %>
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium">Description</label>
                  <textarea name="project[description]" class="w-full border rounded p-2" rows="3"><%= @form_data["description"] %></textarea>
                </div>
              </div>

              <div class="flex justify-end gap-2 mt-6">
                <button type="button" phx-click="close" class="px-4 py-2 rounded border">Cancel</button>
                <button type="submit" class="px-4 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700">Save</button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # =========================
  # Events
  # =========================

  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, show_form: false, form_data: empty_form())}
  end

  def handle_event("update", %{"project" => params}, socket) do
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

  def handle_event("save", %{"project" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      code: params["code"],
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      organization_id: parse_int(params["organization_id"]),
      department_id: parse_int(params["department_id"]),
      program_id: parse_int(params["program_id"]),
      supervisor_id: parse_int(params["supervisor_id"])
    }

    case Eams.create_project(attrs) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form_data, empty_form())
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> assign(:projects, Eams.list_projects())}

      {:error, changeset} ->
        {:noreply, assign(socket, errors: changeset.errors |> Enum.into(%{}))}
    end
  end

  # =========================
  # Helpers
  # =========================

  defp empty_form do
    %{
      "name" => "",
      "description" => "",
      "organization_id" => "",
      "department_id" => "",
      "program_id" => "",
      "supervisor_id" => "",
      "code" => "",
      "starts_on" => "",
      "ends_on" => ""
    }
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
    case Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
