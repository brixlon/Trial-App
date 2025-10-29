defmodule TrialAppWeb.AdminLive.PositionManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Orgs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:positions, Orgs.list_positions())
     |> assign(:search, "")
     |> assign(:editing, nil)
     |> assign(:form, %{name: "", description: ""})}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    q = String.trim(q)
    positions = if q == "", do: Orgs.list_positions(), else: Orgs.search_positions(q)
    {:noreply, assign(socket, positions: positions, search: q)}
  end

  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, editing: nil, form: %{name: "", description: ""})}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    pos = Orgs.get_position!(String.to_integer(id))
    {:noreply, assign(socket, editing: pos.id, form: %{name: pos.name, description: pos.description || ""})}
  end

  def handle_event("save", params, socket) do
    attrs =
      case params do
        %{"position" => attrs} ->
          %{"name" => Map.get(attrs, "name", ""), "description" => Map.get(attrs, "description", "")}

        %{"name" => name} = flat ->
          %{"name" => name, "description" => Map.get(flat, "description", "")}

        _ ->
          %{"name" => "", "description" => ""}
      end

    result =
      case socket.assigns.editing do
        nil -> Orgs.create_position(attrs)
        id -> Orgs.update_position(Orgs.get_position!(id), attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Position saved")
         |> assign(:positions, Orgs.list_positions())
         |> assign(:editing, nil)
         |> assign(:form, %{name: "", description: ""})}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, inspect(changeset.errors))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)
    Orgs.get_position!(id) |> Orgs.delete_position()
    {:noreply, assign(socket, positions: Orgs.list_positions())}
  end

  @impl true
end
