defmodule TrialAppWeb.DepartmentLive.Index do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Departments
        <:actions>
          <.button variant="primary" navigate={~p"/departments/new"}>
            <.icon name="hero-plus" /> New Department
          </.button>
        </:actions>
      </.header>

      <.table
        id="departments"
        rows={@streams.departments}
        row_click={fn {_id, department} -> JS.navigate(~p"/departments/#{department}") end}
      >
        <:col :let={{_id, department}} label="Name">{department.name}</:col>
        <:col :let={{_id, department}} label="Description">{department.description}</:col>
        <:action :let={{_id, department}}>
          <div class="sr-only">
            <.link navigate={~p"/departments/#{department}"}>Show</.link>
          </div>
          <.link navigate={~p"/departments/#{department}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, department}}>
          <.link
            phx-click={JS.push("delete", value: %{id: department.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Organizations.subscribe_departments(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Departments")
     |> stream(:departments, list_departments(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    department = Organizations.get_department!(socket.assigns.current_scope, id)
    {:ok, _} = Organizations.delete_department(socket.assigns.current_scope, department)

    {:noreply, stream_delete(socket, :departments, department)}
  end

  @impl true
  def handle_info({type, %TrialApp.Organizations.Department{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :departments, list_departments(socket.assigns.current_scope), reset: true)}
  end

  defp list_departments(current_scope) do
    Organizations.list_departments(current_scope)
  end
end
