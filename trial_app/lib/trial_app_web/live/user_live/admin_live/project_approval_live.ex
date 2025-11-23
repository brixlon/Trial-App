defmodule TrialAppWeb.AdminLive.ProjectApprovalLive do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Pending Project Approvals")
      |> load_pending_projects()

    {:ok, socket}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    project = Eams.get_project!(id)

    case Eams.approve_project(project) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project approved successfully.")
         |> load_pending_projects()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve project.")}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    project = Eams.get_project!(id)

    case Eams.reject_project(project) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project rejected.")
         |> load_pending_projects()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reject project.")}
    end
  end

  defp load_pending_projects(socket) do
    projects = Eams.list_pending_projects()
    assign(socket, :pending_projects, projects)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-800">Pending Project Approvals</h1>
        <p class="text-gray-600 mt-2">Review and approve projects created by supervisors</p>
      </div>

      <%= if Enum.empty?(@pending_projects) do %>
        <div class="bg-white rounded-lg border border-gray-200 p-12 text-center shadow-sm">
          <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4">
            <svg class="h-6 w-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M5 13l4 4L19 7"
              />
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900">All caught up!</h3>
          <p class="mt-1 text-gray-500">There are no pending projects requiring approval.</p>
        </div>
      <% else %>
        <div class="space-y-6">
          <%= for project <- @pending_projects do %>
            <div class="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
              <div class="p-6">
                <div class="flex justify-between items-start">
                  <div>
                    <div class="flex items-center gap-3 mb-2">
                      <h3 class="text-xl font-bold text-gray-900">{project.name}</h3>
                      <span class="px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                        Pending
                      </span>
                    </div>
                    <p class="text-gray-600 mb-4">{project.description}</p>

                    <div class="grid grid-cols-2 gap-x-8 gap-y-2 text-sm">
                      <div>
                        <span class="text-gray-500">Supervisor:</span>
                        <span class="font-medium text-gray-900 ml-1">
                          {if project.supervisor,
                            do: project.supervisor.username || project.supervisor.email,
                            else: "Unknown"}
                        </span>
                      </div>
                      <div>
                        <span class="text-gray-500">Program:</span>
                        <span class="font-medium text-gray-900 ml-1">
                          {if project.program, do: project.program.name, else: "Unknown"}
                        </span>
                      </div>
                      <div>
                        <span class="text-gray-500">Department:</span>
                        <span class="font-medium text-gray-900 ml-1">
                          {if project.department, do: project.department.name, else: "Unknown"}
                        </span>
                      </div>
                      <div>
                        <span class="text-gray-500">Code:</span>
                        <span class="font-medium text-gray-900 ml-1">{project.code}</span>
                      </div>
                    </div>
                  </div>

                  <div class="flex flex-col gap-3">
                    <button
                      phx-click="approve"
                      phx-value-id={project.id}
                      class="inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 w-32"
                    >
                      Approve
                    </button>
                    <button
                      phx-click="reject"
                      phx-value-id={project.id}
                      data-confirm="Are you sure you want to reject this project?"
                      class="inline-flex items-center justify-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md shadow-sm text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 w-32"
                    >
                      Reject
                    </button>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 px-6 py-3 border-t border-gray-200 flex justify-between items-center text-xs text-gray-500">
                <span>Submitted on {Calendar.strftime(project.inserted_at, "%B %d, %Y")}</span>
                <span>{project.organization.name}</span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
