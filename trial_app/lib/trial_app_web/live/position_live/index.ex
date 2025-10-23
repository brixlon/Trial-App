defmodule TrialAppWeb.PositionLive.Index do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Positions
        <:actions>
          <.button variant="primary" navigate={~p"/positions/new"}>
            <.icon name="hero-plus" /> New Position
          </.button>
        </:actions>
      </.header>

      <.table
        id="positions"
        rows={@streams.positions}
        row_click={fn {_id, position} -> JS.navigate(~p"/positions/#{position}") end}
      >
        <:col :let={{_id, position}} label="Title">{position.title}</:col>
        <:col :let={{_id, position}} label="Description">{position.description}</:col>
        <:action :let={{_id, position}}>
          <div class="sr-only">
            <.link navigate={~p"/positions/#{position}"}>Show</.link>
          </div>
          <.link navigate={~p"/positions/#{position}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, position}}>
          <.link
            phx-click={JS.push("delete", value: %{id: position.id}) |> hide("##{id}")}
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
      Organizations.subscribe_positions(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Positions")
     |> stream(:positions, list_positions(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    position = Organizations.get_position!(socket.assigns.current_scope, id)
    {:ok, _} = Organizations.delete_position(socket.assigns.current_scope, position)

    {:noreply, stream_delete(socket, :positions, position)}
  end

  @impl true
  def handle_info({type, %TrialApp.Organizations.Position{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :positions, list_positions(socket.assigns.current_scope), reset: true)}
  end

  defp list_positions(current_scope) do
    Organizations.list_positions(current_scope)
  end
end
