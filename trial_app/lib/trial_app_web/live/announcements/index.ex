defmodule TrialAppWeb.AnnouncementLive.Index do
  use TrialAppWeb, :live_view

  alias TrialApp.{Announcements, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    active_role = Accounts.get_active_role(user)

    announcements = if active_role in ["admin", "supervisor"] do
      Announcements.list_all_announcements()
    else
      Announcements.list_announcements_for_user(user.id, active_role)
    end

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:current_scope, current_scope)
     |> assign(:active_role, active_role)
     |> assign(:announcements, announcements)
     |> assign(:show_create_modal, false)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    Announcements.mark_as_read(id, socket.assigns.current_user.id)
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    announcement = Announcements.get_announcement!(id)

    # Only allow creator to delete
    if announcement.creator_id == socket.assigns.current_user.id do
      {:ok, _} = Announcements.delete_announcement(announcement)

      # Reload announcements
      user = socket.assigns.current_user
      active_role = socket.assigns.active_role

      announcements = if active_role in ["admin", "supervisor"] do
        Announcements.list_all_announcements()
      else
        Announcements.list_announcements_for_user(user.id, active_role)
      end

      {:noreply, socket |> assign(:announcements, announcements) |> put_flash(:info, "Announcement deleted")}
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own announcements")}
    end
  end

  @impl true
  def handle_info({:announcement_created, _announcement}, socket) do
    # Reload announcements
    user = socket.assigns.current_user
    active_role = socket.assigns.active_role

    announcements = if active_role in ["admin", "supervisor"] do
      Announcements.list_all_announcements()
    else
      Announcements.list_announcements_for_user(user.id, active_role)
    end

    {:noreply,
     socket
     |> assign(:announcements, announcements)
     |> assign(:show_create_modal, false)
     |> put_flash(:info, "Announcement created successfully!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-8">
            <!-- Header -->
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-semibold text-gray-800">Announcements</h1>
                <p class="text-gray-600 mt-1">Stay updated with the latest information</p>
              </div>

              <%= if @active_role in ["admin", "supervisor"] do %>
                <button
                  phx-click="open_create_modal"
                  class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium transition flex items-center gap-2 shadow"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                  New Announcement
                </button>
              <% end %>
            </div>

            <!-- Announcements List -->
            <%= if @announcements == [] do %>
              <div class="bg-white rounded-xl shadow overflow-hidden">
                <div class="p-12 text-center">
                  <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>
                  </svg>
                  <h3 class="text-lg font-semibold text-gray-900 mb-2">No Announcements Yet</h3>
                  <p class="text-gray-600">Check back later for updates</p>
                </div>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for announcement <- @announcements do %>
                  <div class={"bg-white rounded-xl shadow overflow-hidden transition hover:shadow-md #{if announcement.pinned, do: "ring-2 ring-purple-200", else: ""}"}>
                    <div class="p-6">
                      <div class="flex items-start justify-between gap-4">
                        <div class="flex-1">
                          <!-- Badges -->
                          <div class="flex items-center gap-2 flex-wrap mb-3">
                            <%= if announcement.pinned do %>
                              <span class="inline-flex items-center rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium text-purple-700">
                                📌 Pinned
                              </span>
                            <% end %>

                            <span class={"inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium #{priority_badge_class(announcement.priority)}"}>
                              <%= String.upcase(announcement.priority) %>
                            </span>

                            <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-700">
                              <%= format_category(announcement.category) %>
                            </span>

                            <%= if not Announcements.is_read?(announcement.id, @current_user.id) do %>
                              <span class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-700">
                                ⚫ Unread
                              </span>
                            <% end %>
                          </div>

                          <!-- Title -->
                          <h3 class="text-xl font-bold text-gray-900 mb-2">
                            <%= announcement.title %>
                          </h3>

                          <!-- Content -->
                          <p class="text-gray-700 whitespace-pre-wrap mb-4">
                            <%= announcement.content %>
                          </p>

                          <!-- Links -->
                          <%= if length(announcement.links) > 0 do %>
                            <div class="mb-4 space-y-2">
                              <p class="text-sm font-medium text-gray-700">📎 Learning Materials & Links:</p>
                              <%= for link <- announcement.links do %>
                                <a
                                  href={link.url}
                                  target="_blank"
                                  class="block text-sm text-purple-600 hover:text-purple-800 hover:underline flex items-center gap-2"
                                >
                                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                                  </svg>
                                  <%= link.title || link.url %>
                                </a>
                              <% end %>
                            </div>
                          <% end %>

                          <!-- Meta Info -->
                          <div class="flex items-center gap-4 text-sm text-gray-500">
                            <span class="flex items-center gap-1">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                              </svg>
                              <%= announcement.creator.username || announcement.creator.email %>
                            </span>
                            <span>•</span>
                            <span><%= Calendar.strftime(announcement.publish_date, "%B %d, %Y at %I:%M %p") %></span>
                          </div>
                        </div>

                        <!-- Actions -->
                        <div class="flex flex-col gap-2">
                          <%= if @active_role in ["admin", "supervisor"] and announcement.creator_id == @current_user.id do %>
                            <button
                              phx-click="delete"
                              phx-value-id={announcement.id}
                              data-confirm="Are you sure you want to delete this announcement?"
                              class="px-3 py-1.5 text-sm bg-red-100 text-red-700 rounded-lg hover:bg-red-200 font-medium transition"
                            >
                              Delete
                            </button>
                          <% else %>
                            <%= if not Announcements.is_read?(announcement.id, @current_user.id) do %>
                              <button
                                phx-click="mark_read"
                                phx-value-id={announcement.id}
                                class="px-3 py-1.5 text-sm bg-purple-100 text-purple-700 rounded-lg hover:bg-purple-200 font-medium transition"
                              >
                                Mark as Read
                              </button>
                            <% else %>
                              <span class="px-3 py-1.5 text-sm bg-green-100 text-green-700 rounded-lg font-medium">
                                ✓ Read
                              </span>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </main>
      </div>

      <!-- Create Modal -->
      <%= if @show_create_modal do %>
        <.live_component
          module={TrialAppWeb.AnnouncementLive.FormComponent}
          id="announcement-form"
          current_user={@current_user}
          active_role={@active_role}
        />
      <% end %>
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
end
