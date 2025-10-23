defmodule TrialAppWeb.EmployeeLive.Index do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Employees
        <:actions>
          <.button variant="primary" navigate={~p"/employees/new"}>
            <.icon name="hero-plus" /> New Employee
          </.button>
        </:actions>
      </.header>

      <.table
        id="employees"
        rows={@streams.employees}
        row_click={fn {_id, employee} -> JS.navigate(~p"/employees/#{employee}") end}
      >
        <:col :let={{_id, employee}} label="Name">{employee.name}</:col>
        <:col :let={{_id, employee}} label="Email">{employee.email}</:col>
        <:col :let={{_id, employee}} label="Position">{employee.position}</:col>
        <:action :let={{_id, employee}}>
          <div class="sr-only">
            <.link navigate={~p"/employees/#{employee}"}>Show</.link>
          </div>
          <.link navigate={~p"/employees/#{employee}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, employee}}>
          <.link
            phx-click={JS.push("delete", value: %{id: employee.id}) |> hide("##{id}")}
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
      Organizations.subscribe_employees(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Employees")
     |> stream(:employees, list_employees(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    employee = Organizations.get_employee!(socket.assigns.current_scope, id)
    {:ok, _} = Organizations.delete_employee(socket.assigns.current_scope, employee)

    {:noreply, stream_delete(socket, :employees, employee)}
  end

  @impl true
  def handle_info({type, %TrialApp.Organizations.Employee{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :employees, list_employees(socket.assigns.current_scope), reset: true)}
  end

  defp list_employees(current_scope) do
    Organizations.list_employees(current_scope)
  end
end
