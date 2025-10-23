defmodule TrialAppWeb.EmployeeLive.Show do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Employee {@employee.id}
        <:subtitle>This is a employee record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/employees"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/employees/#{@employee}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit employee
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@employee.name}</:item>
        <:item title="Email">{@employee.email}</:item>
        <:item title="Position">{@employee.position}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Organizations.subscribe_employees(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Employee")
     |> assign(:employee, Organizations.get_employee!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %TrialApp.Organizations.Employee{id: id} = employee},
        %{assigns: %{employee: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :employee, employee)}
  end

  def handle_info(
        {:deleted, %TrialApp.Organizations.Employee{id: id}},
        %{assigns: %{employee: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current employee was deleted.")
     |> push_navigate(to: ~p"/employees")}
  end

  def handle_info({type, %TrialApp.Organizations.Employee{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
