defmodule TrialAppWeb.AdminLive.TaskManagement do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:tasks, Eams.list_tasks())
     |> assign(:show_form, false)
     |> assign(:projects, Eams.list_projects())
     |> assign(:attachees, Eams.list_attachees())
     |> assign(:form_data, %{"title" => "", "description" => "", "status" => "pending", "due_on" => "", "project_id" => "", "assignee_id" => ""})
     |> assign(:errors, %{})}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />
    <div class="ml-64 p-8">
      <h1 class="text-2xl font-bold mb-4">Tasks</h1>
      <div class="flex justify-end mb-3">
        <button phx-click="new" class="px-4 py-2 rounded-lg bg-indigo-600 text-white">New Task</button>
      </div>
      <div class="bg-white rounded-xl border p-4">
        <%= if @tasks == [] do %>
          <p class="text-gray-600">No tasks yet.</p>
        <% else %>
          <ul class="space-y-2">
            <%= for t <- @tasks do %>
              <li class="border rounded-lg p-3">
                <div class="font-semibold">{t.title}</div>
                <div class="text-sm text-gray-500">Status: {t.status}</div>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4">
          <div class="bg-white rounded-xl w-full max-w-lg p-6">
            <h2 class="text-xl font-bold mb-4">Create Task</h2>
            <.form for={to_form(@form_data, as: :task)} id="task-form" phx-submit="save" phx-change="update">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium">Title</label>
                  <input name="title" value={@form_data["title"]} class="w-full border rounded p-2" required />
                </div>
                <div>
                  <label class="block text-sm font-medium">Project</label>
                  <select name="project_id" class="w-full border rounded p-2" required>
                    <option value="">Select project</option>
                    <%= for p <- @projects do %>
                      <option value={p.id} selected={to_string(p.id) == @form_data["project_id"]}>{p.name}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium">Assignee (Attachee)</label>
                  <select name="assignee_id" class="w-full border rounded p-2" required>
                    <option value="">Select attachee</option>
                    <%= for a <- @attachees do %>
                      <option value={a.id} selected={to_string(a.id) == @form_data["assignee_id"]}>{a.user && (a.user.username || a.user.email) || ("Attachee " <> to_string(a.id))}</option>
                    <% end %>
                  </select>
                </div>
                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium">Due date</label>
                    <input type="date" name="due_on" value={@form_data["due_on"]} class="w-full border rounded p-2" />
                  </div>
                  <div>
                    <label class="block text-sm font-medium">Status</label>
                    <select name="status" class="w-full border rounded p-2">
                      <%= for s <- ["pending","in_progress","blocked","completed","cancelled"] do %>
                        <option value={s} selected={s == @form_data["status"]}>{s}</option>
                      <% end %>
                    </select>
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium">Description</label>
                  <textarea name="description" class="w-full border rounded p-2" rows="3"><%= @form_data["description"] %></textarea>
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

  def handle_event("update", %{"task" => params}, socket) do
    socket = assign(socket, form_data: Map.merge(socket.assigns.form_data, params))

    socket =
      case Map.get(params, "project_id") do
        nil -> socket
        "" -> socket
        proj_id_str ->
          project = Eams.get_project!(String.to_integer(proj_id_str))
          attachees = Eams.list_attachees_by_program(project.program_id, %{preloads: [:user]})
          assign(socket, attachees: attachees)
      end

    {:noreply, socket}
  end

  def handle_event("save", %{"task" => params}, socket) do
    attrs = %{
      title: params["title"],
      description: params["description"],
      status: params["status"],
      due_on: parse_date(params["due_on"]),
      project_id: parse_int(params["project_id"]),
      assignee_id: parse_int(params["assignee_id"])
    }

    case Eams.create_task(attrs) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:form_data, %{"title" => "", "description" => "", "status" => "pending", "due_on" => "", "project_id" => "", "assignee_id" => ""})
         |> assign(:tasks, Eams.list_tasks())
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
end
