defmodule TrialAppWeb.PositionLive.Index do
  use TrialAppWeb, :live_view
  alias TrialApp.Orgs

  def mount(_params, _session, socket) do
    positions = Orgs.list_positions()

    {:ok,
     socket
     |> assign(:page_title, "Positions")
     |> assign(:positions, positions)
     |> assign(:search, "")
     |> assign(:sort_by, "name")
     |> assign(:sort_order, "asc")
     |> assign(:view_mode, "grid")
     |> assign(:stats, calculate_stats(positions))
     |> stream(:positions, sort_positions(positions, "name", "asc"))}
  end

  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    q = String.trim(q)
    positions = if q == "", do: Orgs.list_positions(), else: Orgs.search_positions(q)

    sorted_positions = sort_positions(positions, socket.assigns.sort_by, socket.assigns.sort_order)

    {:noreply,
     socket
     |> assign(:positions, positions)
     |> assign(:search, q)
     |> assign(:stats, calculate_stats(positions))
     |> stream(:positions, sorted_positions, reset: true)}
  end

  def handle_event("sort", %{"by" => field}, socket) do
    current_sort = socket.assigns.sort_by
    current_order = socket.assigns.sort_order

    # Toggle order if same field, otherwise default to asc
    new_order = if current_sort == field and current_order == "asc", do: "desc", else: "asc"

    sorted_positions = sort_positions(socket.assigns.positions, field, new_order)

    {:noreply,
     socket
     |> assign(:sort_by, field)
     |> assign(:sort_order, new_order)
     |> stream(:positions, sorted_positions, reset: true)}
  end

  def handle_event("toggle_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    position = Orgs.get_position!(id)

    case Orgs.delete_position(position) do
      {:ok, _pos} ->
        positions = Orgs.list_positions()

        {:noreply,
         socket
         |> put_flash(:info, "Position deleted successfully")
         |> assign(:positions, positions)
         |> assign(:stats, calculate_stats(positions))
         |> stream_delete(:positions, position)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete position")}
    end
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
  def truncate(text, length \\ 80) do
    if text && String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text || "—"
    end
  end

  # Helper: Get position initial
  def get_position_initial(name) do
    name
    |> String.first()
    |> String.upcase()
  end

  # Helper: Check if search matches position
  def matches_search?(position, search) when search == "" or is_nil(search), do: true

  def matches_search?(position, search) do
    search = String.downcase(search)

    String.contains?(String.downcase(position.name || ""), search) ||
      String.contains?(String.downcase(position.description || ""), search)
  end
end
