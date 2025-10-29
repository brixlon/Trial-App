defmodule TrialAppWeb.PositionLive.Index do
  use TrialAppWeb, :live_view

  alias TrialApp.Orgs

  def mount(_params, _session, socket) do
    positions = Orgs.list_positions()

    {:ok,
      socket
      |> assign(:page_title, "Positions")
      |> stream(:positions, positions)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    position = Orgs.get_position!(id)

    case Orgs.delete_position(position) do
      {:ok, _pos} ->
        {:noreply,
          socket
          |> put_flash(:info, "Position deleted")
          |> stream_delete(:positions, position)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete position")}
    end
  end
end
