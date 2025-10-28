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

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <div class="max-w-7xl mx-auto">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-3xl font-bold">Positions</h1>
          <.link navigate={~p"/admin/positions"} class="btn btn-primary btn-soft">Manage</.link>
        </div>
        <div id="positions" phx-update="stream" class="bg-base-100 border border-base-300 rounded-xl shadow-sm">
          <table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Title</th>
                <th>Description</th>
                <th class="w-40">Actions</th>
              </tr>
            </thead>
            <tbody>
              <div class="hidden only:block p-4 text-base-content/60">No positions yet</div>
              <%= for {pos_dom_id, pos} <- @streams.positions do %>
                <tr id={pos_dom_id} class="hover">
                  <td class="font-medium">{pos.name}</td>
                  <td>{pos.title}</td>
                  <td class="text-base-content/70">{pos.description}</td>
                  <td>
                    <div class="flex gap-2">
                      <button class="btn btn-xs">Show</button>
                      <button class="btn btn-xs" phx-click="edit" phx-value-id={pos.id}>Edit</button>
                      <button class="btn btn-xs btn-error" phx-click="delete" phx-value-id={pos.id}>Delete</button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        <div class="mt-4">
          <.link navigate={~p"/admin/positions"} class="btn btn-primary">New Position</.link>
        </div>
      </div>
    </Layouts.app>
    """
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
