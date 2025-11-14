defmodule TrialAppWeb.AnnouncementsWidget do
  use TrialAppWeb, :live_component

  alias TrialApp.Announcements

  @impl true
  def update(assigns, socket) do
    current_user = assigns.current_user
    active_role = assigns.active_role

    announcements =
      Announcements.list_announcements_for_user(current_user.id, active_role)
      |> Enum.take(3)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:announcements, announcements)}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    Announcements.mark_as_read(id, socket.assigns.current_user.id)

    # Refresh announcements
    current_user = socket.assigns.current_user
    active_role = socket.assigns.active_role
    announcements =
      Announcements.list_announcements_for_user(current_user.id, active_role)
      |> Enum.take(3)

    {:noreply, assign(socket, :announcements, announcements)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-xl overflow-hidden">
      <div class="p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-800">Announcements</h3>
          <.link
            navigate={~p"/announcements"}
            class="text-sm font-medium text-purple-600 hover:text-purple-800"
          >
            View All
          </.link>
        </div>

        <%= if length(@announcements) > 0 do %>
          <div class="space-y-3">
            <%= for announcement <- @announcements do %>
              <div class="p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition">
                <div class="flex items-start justify-between gap-3">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 flex-wrap mb-2">
                      <%= if announcement.pinned do %>
                        <span class="inline-flex items-center rounded-full bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-700">
                          📌
                        </span>
                      <% end %>

                      <span class={"inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{priority_badge_class(announcement.priority)}"}>
                        <%= String.upcase(announcement.priority) %>
                      </span>

                      <span class="inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">
                        <%= format_category(announcement.category) %>
                      </span>
                    </div>

                    <h4 class="text-sm font-semibold text-gray-900 mb-1">
                      <%= announcement.title %>
                    </h4>

                    <p class="text-sm text-gray-600 line-clamp-2 mb-2">
                      <%= announcement.content %>
                    </p>

                    <%= if length(announcement.links) > 0 do %>
                      <div class="flex items-center gap-1 text-xs text-purple-600 mb-2">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                        </svg>
                        <span><%= length(announcement.links) %> link(s)</span>
                      </div>
                    <% end %>

                    <div class="flex items-center gap-3 text-xs text-gray-500">
                      <span><%= format_relative_time(announcement.publish_date) %></span>
                      <%= if not Announcements.is_read?(announcement.id, @current_user.id) do %>
                        <span class="inline-flex items-center text-blue-600 font-medium">
                          • Unread
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <%= if not Announcements.is_read?(announcement.id, @current_user.id) do %>
                    <button
                      phx-click="mark_read"
                      phx-value-id={announcement.id}
                      phx-target={@myself}
                      class="flex-shrink-0 text-xs text-purple-600 hover:text-purple-800 font-medium px-2 py-1 rounded hover:bg-purple-50"
                    >
                      Mark Read
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-10 text-gray-500">
            <svg class="mx-auto h-12 w-12 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>
            </svg>
            <p class="text-sm">No announcements yet</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp priority_badge_class("urgent"), do: "bg-red-100 text-red-700"
  defp priority_badge_class("important"), do: "bg-yellow-100 text-yellow-700"
  defp priority_badge_class("normal"), do: "bg-gray-100 text-gray-700"

  defp format_category(category) do
    category
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
