defmodule TrialAppWeb.DepartmentLive.Show do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-gradient-to-br from-gray-50 via-white to-gray-100 py-10 px-6">
        <div class="max-w-4xl mx-auto bg-white shadow-xl rounded-2xl p-8 border border-gray-200">

          <div class="flex items-center justify-between mb-6">
            <div>
              <h1 class="text-3xl font-bold text-gray-800 flex items-center gap-2">
                <.icon name="hero-building-office" class="text-blue-500 w-8 h-8" />
                Department Details
              </h1>
              <p class="text-gray-500 mt-1">View and manage department information</p>
            </div>

            <div class="flex gap-3">
              <.button variant="secondary" navigate={~p"/departments"}>
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> Back
              </.button>

              <.button variant="primary" navigate={~p"/departments/#{@department}/edit?return_to=show"}>
                <.icon name="hero-pencil-square" class="w-4 h-4 mr-1" /> Edit
              </.button>
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 mt-6">
            <div class="p-5 bg-gray-50 rounded-xl border border-gray-200">
              <h2 class="text-sm text-gray-500 uppercase mb-2">Department Name</h2>
              <p class="text-lg font-semibold text-gray-800 truncate">
                {@department.name}
              </p>
            </div>

            <div class="p-5 bg-gray-50 rounded-xl border border-gray-200">
              <h2 class="text-sm text-gray-500 uppercase mb-2">Description</h2>
              <p class="text-gray-700 leading-relaxed">
                {@department.description || "No description provided."}
              </p>
            </div>
          </div>

          <div class="mt-8 text-sm text-gray-400 border-t pt-4">
            <p>Department ID: <span class="font-mono text-gray-600">{@department.id}</span></p>
          </div>

        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Organizations.subscribe_departments(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Department")
     |> assign(:department, Organizations.get_department!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info({:updated, %TrialApp.Organizations.Department{id: id} = department}, %{assigns: %{department: %{id: id}}} = socket) do
    {:noreply, assign(socket, :department, department)}
  end

  def handle_info({:deleted, %TrialApp.Organizations.Department{id: id}}, %{assigns: %{department: %{id: id}}} = socket) do
    {:noreply,
     socket
     |> put_flash(:error, "The current department was deleted.")
     |> push_navigate(to: ~p"/departments")}
  end

  def handle_info({type, %TrialApp.Organizations.Department{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
