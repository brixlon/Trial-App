defmodule TrialAppWeb.PositionLive.Show do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Position {@position.id}
        <:subtitle>This is a position record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/positions"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/positions/#{@position}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit position
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@position.title}</:item>
        <:item title="Description">{@position.description}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Organizations.subscribe_positions(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Position")
     |> assign(:position, Organizations.get_position!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %TrialApp.Organizations.Position{id: id} = position},
        %{assigns: %{position: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :position, position)}
  end

  def handle_info(
        {:deleted, %TrialApp.Organizations.Position{id: id}},
        %{assigns: %{position: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current position was deleted.")
     |> push_navigate(to: ~p"/positions")}
  end

  def handle_info({type, %TrialApp.Organizations.Position{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
