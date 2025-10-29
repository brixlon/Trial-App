defmodule TrialAppWeb.AdminLive.PositionManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Orgs

  @impl true
  def mount(_params, _session, socket) do
    positions = Orgs.list_positions()

    {:ok,
     socket
     |> assign(:page_title, "Position Management")
     |> assign(:positions, positions)
     |> assign(:filtered_positions, positions)
     |> assign(:search, "")
     |> assign(:editing, nil)
     |> assign(:show_form, false)
     |> assign(:form, %{name: "", description: ""})
     |> assign(:sort_by, "name")
     |> assign(:sort_order, "asc")
     |> assign(:stats, calculate_stats(positions))}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    q = String.trim(q)
    positions = if q == "", do: Orgs.list_positions(), else: Orgs.search_positions(q)

    sorted_positions = sort_positions(positions, socket.assigns.sort_by, socket.assigns.sort_order)

    {:noreply,
     socket
     |> assign(:positions, positions)
     |> assign(:filtered_positions, sorted_positions)
     |> assign(:search, q)}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, nil)
     |> assign(:show_form, true)
     |> assign(:form, %{name: "", description: ""})}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    pos = Orgs.get_position!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:editing, pos.id)
     |> assign(:show_form, true)
     |> assign(:form, %{name: pos.name, description: pos.description || ""})}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, nil)
     |> assign(:show_form, false)
     |> assign(:form, %{name: "", description: ""})}
  end

  @impl true
  def handle_event("save", params, socket) do
    attrs =
      case params do
        %{"position" => attrs} ->
          %{
            "name" => String.trim(Map.get(attrs, "name", "")),
            "description" => String.trim(Map.get(attrs, "description", ""))
          }

        %{"name" => name} = flat ->
          %{
            "name" => String.trim(name),
            "description" => String.trim(Map.get(flat, "description", ""))
          }

        _ ->
          %{"name" => "", "description" => ""}
      end

    # Validate
    if attrs["name"] == "" do
      {:noreply, put_flash(socket, :error, "Position name is required")}
    else
      result =
        case socket.assigns.editing do
          nil -> Orgs.create_position(attrs)
          id -> Orgs.update_position(Orgs.get_position!(id), attrs)
        end

      case result do
        {:ok, _position} ->
          positions = Orgs.list_positions()
          sorted_positions = sort_positions(positions, socket.assigns.sort_by, socket.assigns.sort_order)

          message = if socket.assigns.editing, do: "Position updated successfully", else: "Position created successfully"

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> assign(:positions, positions)
           |> assign(:filtered_positions, sorted_positions)
           |> assign(:editing, nil)
           |> assign(:show_form, false)
           |> assign(:form, %{name: "", description: ""})
           |> assign(:stats, calculate_stats(positions))}

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")

          {:noreply, put_flash(socket, :error, "Error: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)
    position = Orgs.get_position!(id)

    case Orgs.delete_position(position) do
      {:ok, _} ->
        positions = Orgs.list_positions()
        sorted_positions = sort_positions(positions, socket.assigns.sort_by, socket.assigns.sort_order)

        {:noreply,
         socket
         |> put_flash(:info, "Position deleted successfully")
         |> assign(:positions, positions)
         |> assign(:filtered_positions, sorted_positions)
         |> assign(:stats, calculate_stats(positions))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete position")}
    end
  end

  @impl true
  def handle_event("sort", %{"by" => field}, socket) do
    current_sort = socket.assigns.sort_by
    current_order = socket.assigns.sort_order

    # Toggle order if same field, otherwise default to asc
    new_order = if current_sort == field and current_order == "asc", do: "desc", else: "asc"

    sorted_positions = sort_positions(socket.assigns.filtered_positions, field, new_order)

    {:noreply,
     socket
     |> assign(:sort_by, field)
     |> assign(:sort_order, new_order)
     |> assign(:filtered_positions, sorted_positions)}
  end

  # Private helper functions
  defp calculate_stats(positions) do
    total = length(positions)
    with_description = Enum.count(positions, fn p -> p.description && p.description != "" end)
    without_description = total - with_description

    %{
      total: total,
      with_description: with_description,
      without_description: without_description
    }
  end

  defp sort_positions(positions, sort_by, sort_order) do
    sorted =
      case sort_by do
        "name" ->
          Enum.sort_by(positions, & String.downcase(&1.name || ""))

        "description" ->
          Enum.sort_by(positions, & String.downcase(&1.description || ""))

        _ ->
          positions
      end

    if sort_order == "desc", do: Enum.reverse(sorted), else: sorted
  end

  # Helper: Get sort icon
  def get_sort_icon(current_sort, target_sort, current_order) do
    if current_sort == target_sort do
      if current_order == "asc", do: "hero-chevron-up", else: "hero-chevron-down"
    else
      "hero-chevron-up-down"
    end
  end

  # Helper: Check if position has description
  def has_description?(position) do
    position.description && position.description != ""
  end

  # Helper: Truncate text
  def truncate(text, length \\ 50) do
    if text && String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text || "—"
    end
  end

  @impl true
end
