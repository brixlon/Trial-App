defmodule TrialAppWeb.SupervisorLive.Projects do
  use TrialAppWeb, :live_view

  alias TrialApp.{Eams, Orgs}
  alias TrialApp.Eams.Project

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Get supervisor's department to filter programs/attachees
    department = Orgs.get_department_for_user(current_user.id)

    socket =
      socket
      |> assign(:department, department)
      |> assign(:show_create_modal, false)
      |> assign(:form, to_form(Project.changeset(%Project{}, %{})))
      |> assign(:programs, [])
      |> assign(:attachees, [])
      |> assign(:selected_attachees, [])
      |> assign(:attachee_search, "")
      |> load_projects()

    {:ok, socket}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    department = socket.assigns.department

    programs =
      if department do
        Eams.list_programs_by_department(department.id)
      else
        []
      end

    # Load potential attachees (from same department)
    attachees =
      if department do
        Eams.list_attachees_by_department(department.id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:programs, programs)
     |> assign(:attachees, attachees)
     |> assign(:selected_attachees, [])
     |> assign(:attachee_search, "")
     |> assign(:form, to_form(Project.changeset(%Project{}, %{})))}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("search_attachees", %{"value" => query}, socket) do
    {:noreply, assign(socket, :attachee_search, query)}
  end

  @impl true
  def handle_event("toggle_attachee", %{"id" => id}, socket) do
    selected = socket.assigns.selected_attachees
    id = String.to_integer(id)

    new_selected =
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end

    {:noreply, assign(socket, :selected_attachees, new_selected)}
  end

  @impl true
  def handle_event("save_project", %{"project" => project_params}, socket) do
    current_user = socket.assigns.current_user
    department = socket.assigns.department

    if !department do
      {:noreply,
       put_flash(socket, :error, "You must belong to a department to create a project.")}
    else
      project_params =
        project_params
        |> Map.put("supervisor_id", current_user.id)
        |> Map.put("department_id", department.id)
        |> Map.put("organization_id", department.organization_id)
        |> Map.put("status", "pending")
        # Pending projects are inactive until approved
        |> Map.put("is_active", false)

      case Eams.create_project(project_params) do
        {:ok, project} ->
          # Assign selected attachees
          Enum.each(socket.assigns.selected_attachees, fn attachee_id ->
            Eams.add_attachee_to_project(project.id, attachee_id, %{
              role: "Intern",
              joined_at: Date.utc_today()
            })
          end)

          {:noreply,
           socket
           |> assign(:show_create_modal, false)
           |> put_flash(
             :info,
             "Project created successfully! It is pending approval from an admin."
           )
           |> load_projects()}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    end
  end

  defp load_projects(socket) do
    current_user = socket.assigns.current_user
    projects = Eams.list_projects_for_supervisor(current_user.id)
    assign(socket, :projects, projects)
  end

  defp filter_attachees(attachees, query) do
    if query == "" do
      attachees
    else
      q = String.downcase(query)

      Enum.filter(attachees, fn a ->
        name = a.user.username || a.user.email
        String.contains?(String.downcase(name), q)
      end)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-800">Projects</h1>
          <p class="text-gray-600 mt-2">View and manage projects assigned to your team</p>
        </div>
        <button
          phx-click="open_create_modal"
          class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition shadow-sm flex items-center gap-2"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"
              clip-rule="evenodd"
            />
          </svg>
          Create Project
        </button>
      </div>

      <%= if Enum.empty?(@projects) do %>
        <div class="bg-gray-50 rounded-lg border border-gray-200 p-12 text-center">
          <svg
            class="mx-auto h-12 w-12 text-gray-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No projects</h3>
          <p class="mt-1 text-sm text-gray-500">Get started by creating a new project.</p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for project <- @projects do %>
            <div class="bg-white rounded-xl border border-gray-200 p-6 hover:shadow-md transition flex flex-col h-full">
              <div class="flex justify-between items-start mb-4">
                <div class={"px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(project.status)}"}>
                  {String.capitalize(project.status || "pending")}
                </div>
                <span class="text-xs text-gray-500">{project.code}</span>
              </div>

              <h3 class="text-lg font-bold text-gray-900 mb-2">{project.name}</h3>
              <p class="text-gray-600 text-sm mb-4 flex-grow line-clamp-3">{project.description}</p>

              <div class="mt-auto pt-4 border-t border-gray-100 flex items-center justify-between">
                <div class="text-xs text-gray-500">
                  {if project.program, do: project.program.name, else: "No Program"}
                </div>
                <%= if project.status == "active" do %>
                  <a
                    href="#"
                    class="text-purple-600 hover:text-purple-700 text-sm font-medium flex items-center gap-1"
                  >
                    Manage
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </a>
                <% else %>
                  <span class="text-gray-400 text-sm cursor-not-allowed">Pending Approval</span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @show_create_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div
              class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
              aria-hidden="true"
              phx-click="close_modal"
            >
            </div>

            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
              &#8203;
            </span>

            <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                    <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                      Create New Project
                    </h3>
                    <div class="mt-4">
                      <.form for={@form} phx-submit="save_project" class="space-y-4">
                        <div>
                          <label class="block text-sm font-medium text-gray-700">Project Name</label>
                          <.input
                            field={@form[:name]}
                            type="text"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                            placeholder="e.g. Mobile App Redesign"
                          />
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700">
                            Project Code (UPPER_CASE)
                          </label>
                          <.input
                            field={@form[:code]}
                            type="text"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                            placeholder="e.g. MOB_APP_01"
                          />
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700">Program</label>
                          <.input
                            field={@form[:program_id]}
                            type="select"
                            options={Enum.map(@programs, &{&1.name, &1.id})}
                            prompt="Select a Program"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                          />
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700">Description</label>
                          <.input
                            field={@form[:description]}
                            type="textarea"
                            rows="3"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                          />
                        </div>

                        <div class="grid grid-cols-2 gap-4">
                          <div>
                            <label class="block text-sm font-medium text-gray-700">Start Date</label>
                            <.input
                              field={@form[:starts_on]}
                              type="date"
                              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                            />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-gray-700">End Date</label>
                            <.input
                              field={@form[:ends_on]}
                              type="date"
                              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm"
                            />
                          </div>
                        </div>

                        <div class="border-t border-gray-200 pt-4 mt-4">
                          <label class="block text-sm font-medium text-gray-700 mb-2">
                            Assign Attachees
                          </label>
                          <input
                            type="text"
                            placeholder="Search attachees..."
                            phx-keyup="search_attachees"
                            phx-debounce="300"
                            class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm mb-3 focus:ring-purple-500 focus:border-purple-500"
                          />

                          <div class="max-h-48 overflow-y-auto border border-gray-200 rounded-md divide-y divide-gray-100">
                            <%= for attachee <- filter_attachees(@attachees, @attachee_search) do %>
                              <div
                                phx-click="toggle_attachee"
                                phx-value-id={attachee.id}
                                class={"p-3 flex items-center justify-between cursor-pointer hover:bg-gray-50 #{if attachee.id in @selected_attachees, do: "bg-purple-50", else: ""}"}
                              >
                                <div class="flex items-center gap-3">
                                  <div class="h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center text-xs font-medium text-gray-600">
                                    {String.first(attachee.user.username || attachee.user.email)
                                    |> String.upcase()}
                                  </div>
                                  <div>
                                    <p class="text-sm font-medium text-gray-900">
                                      {attachee.user.username || attachee.user.email}
                                    </p>
                                    <p class="text-xs text-gray-500">{attachee.user.email}</p>
                                  </div>
                                </div>
                                <div class={"h-5 w-5 rounded border flex items-center justify-center #{if attachee.id in @selected_attachees, do: "bg-purple-600 border-purple-600", else: "border-gray-300"}"}>
                                  <%= if attachee.id in @selected_attachees do %>
                                    <svg
                                      class="h-3 w-3 text-white"
                                      fill="none"
                                      viewBox="0 0 24 24"
                                      stroke="currentColor"
                                    >
                                      <path
                                        stroke-linecap="round"
                                        stroke-linejoin="round"
                                        stroke-width="3"
                                        d="M5 13l4 4L19 7"
                                      />
                                    </svg>
                                  <% end %>
                                </div>
                              </div>
                            <% end %>

                            <%= if Enum.empty?(filter_attachees(@attachees, @attachee_search)) do %>
                              <div class="p-4 text-center text-sm text-gray-500">
                                No attachees found
                              </div>
                            <% end %>
                          </div>
                          <p class="text-xs text-gray-500 mt-1">
                            {length(@selected_attachees)} attachees selected
                          </p>
                        </div>

                        <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                          <button
                            type="submit"
                            class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-purple-600 text-base font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm"
                          >
                            Create Project
                          </button>
                          <button
                            type="button"
                            phx-click="close_modal"
                            class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
                          >
                            Cancel
                          </button>
                        </div>
                      </.form>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_color("active"), do: "bg-green-100 text-green-800"
  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("rejected"), do: "bg-red-100 text-red-800"
  defp status_color("completed"), do: "bg-blue-100 text-blue-800"
  defp status_color("archived"), do: "bg-gray-100 text-gray-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"
end
