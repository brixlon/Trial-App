defmodule TrialAppWeb.DepartmentLive.Show do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Department {@department.id}
        <:subtitle>This is a department record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/departments"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/departments/#{@department}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit department
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@department.name}</:item>
        <:item title="Description">{@department.description}</:item>
      </.list>
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
  def handle_info(
        {:updated, %TrialApp.Organizations.Department{id: id} = department},
        %{assigns: %{department: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :department, department)}
  end

  def handle_info(
        {:deleted, %TrialApp.Organizations.Department{id: id}},
        %{assigns: %{department: %{id: id}}} = socket
      ) do
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
