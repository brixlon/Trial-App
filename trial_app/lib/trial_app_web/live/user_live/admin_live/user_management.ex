defmodule TrialAppWeb.AdminLive.UserManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts

  def mount(_params, _session, socket) do
    # Load all users for the admin
    users = Accounts.list_users()

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:filter, "all") # all, pending, active
     |> assign(:selected_user, nil)
     |> assign(:show_edit_modal, false)
     |> assign(:departments, []) # Initialize empty for now
     |> assign(:teams, []) # Initialize empty for now
    }
  end

  def handle_params(params, _url, socket) do
    filter = Map.get(params, "filter", "all")
    users = apply_filter(Accounts.list_users(), filter)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:filter, filter)
    }
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" socket={@socket} />

        <main class="ml-64 w-full p-8">
          <div class="max-w-6xl mx-auto">
            <!-- Header -->
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-gray-900">User Management</h1>
              <p class="text-gray-600 mt-2">Manage user accounts and assignments</p>
            </div>

            <!-- Filter Tabs -->
            <div class="mb-6">
              <div class="border-b border-gray-200">
                <nav class="-mb-px flex space-x-8">
                  <.link
                    patch={~p"/admin/users?filter=all"}
                    class={[
                      "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm",
                      @filter == "all" && "border-blue-500 text-blue-600",
                      @filter != "all" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    All Users
                    <span class="ml-2 bg-gray-100 text-gray-900 py-0.5 px-2 rounded-full text-xs">
                      <%= Enum.count(@users) %>
                    </span>
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=pending"}
                    class={[
                      "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm",
                      @filter == "pending" && "border-yellow-500 text-yellow-600",
                      @filter != "pending" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Pending Approval
                    <span class="ml-2 bg-yellow-100 text-yellow-800 py-0.5 px-2 rounded-full text-xs">
                      <%= Enum.count(@users, &(&1.status == "pending")) %>
                    </span>
                  </.link>

                  <.link
                    patch={~p"/admin/users?filter=active"}
                    class={[
                      "whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm",
                      @filter == "active" && "border-green-500 text-green-600",
                      @filter != "active" && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    ]}
                  >
                    Active Users
                    <span class="ml-2 bg-green-100 text-green-800 py-0.5 px-2 rounded-full text-xs">
                      <%= Enum.count(@users, &(&1.status == "active")) %>
                    </span>
                  </.link>
                </nav>
              </div>
            </div>

            <!-- Users Table -->
            <div class="bg-white border border-gray-200 rounded-lg shadow-sm">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      User
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Role
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Registered
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for user <- @users do %>
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex items-center">
                          <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                            <span class="text-blue-600 font-semibold text-sm">
                              <%= String.at(user.username, 0) |> String.upcase() %>
                            </span>
                          </div>
                          <div>
                            <div class="text-sm font-medium text-gray-900">
                              <%= user.username %>
                            </div>
                            <div class="text-sm text-gray-500">
                              <%= user.email %>
                            </div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                          user_status_class(user.status)
                        ]}>
                          <%= user_status_label(user.status) %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= String.capitalize(user.role) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= Timex.format!(user.inserted_at, "{M}/{D}/{YYYY}") %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <%= if user.status == "pending" do %>
                          <button
                            phx-click="approve_user"
                            phx-value-user-id={user.id}
                            class="text-green-600 hover:text-green-900 mr-3"
                          >
                            Approve
                          </button>
                        <% end %>

                        <%= if user.status == "active" && user.role == "user" do %>
                          <button
                            phx-click="make_admin"
                            phx-value-user-id={user.id}
                            class="text-purple-600 hover:text-purple-900 mr-3"
                          >
                            Make Admin
                          </button>
                        <% end %>

                        <button
                          phx-click="edit_user"
                          phx-value-user-id={user.id}
                          class="text-blue-600 hover:text-blue-900 mr-3"
                        >
                          Edit
                        </button>

                        <button
                          phx-click="view_user"
                          phx-value-user-id={user.id}
                          class="text-gray-600 hover:text-gray-900"
                        >
                          View
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@users) do %>
                <div class="text-center py-12">
                  <svg class="w-12 h-12 mx-auto text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No users found</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    <%= if @filter == "pending" do %>
                      No users are waiting for approval.
                    <% else %>
                      Get started by creating a new user.
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </main>
      </div>

      <!-- Edit User Modal -->
      <%= if @show_edit_modal && @selected_user do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div class="relative top-20 mx-auto p-5 border w-full max-w-2xl shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex justify-between items-center pb-4 border-b">
                <h3 class="text-lg font-medium text-gray-900">
                  Edit User: <%= @selected_user.username %>
                </h3>
                <button
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <div class="mt-4">
                <p class="text-sm text-gray-600 mb-4">
                  Employee assignment feature coming soon. The database structure is ready,
                  but we need to create the Employee module first.
                </p>

                <div class="flex justify-end space-x-3 pt-4 border-t">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Close
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("approve_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_status(user, "active") do
      {:ok, _user} ->
        # Refresh the user list
        users = apply_filter(Accounts.list_users(), socket.assigns.filter)

        {:noreply,
         socket
         |> put_flash(:info, "User approved successfully!")
         |> assign(:users, users)
        }

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to approve user")}
    end
  end

  def handle_event("make_admin", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_role(user, "admin") do
      {:ok, _user} ->
        users = apply_filter(Accounts.list_users(), socket.assigns.filter)

        {:noreply,
         socket
         |> put_flash(:info, "User promoted to admin!")
         |> assign(:users, users)
        }

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to promote user to admin")}
    end
  end

  def handle_event("edit_user", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Accounts.get_user!(user_id)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_edit_modal, true)
     |> put_flash(:info, "Edit functionality coming soon! We need to create the Employee module first.")
    }
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:selected_user, nil)
    }
  end

  def handle_event("view_user", %{"user-id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    {:noreply, put_flash(socket, :info, "Viewing user #{user_id}")}
  end

  defp apply_filter(users, "all"), do: users
  defp apply_filter(users, "pending"), do: Enum.filter(users, &(&1.status == "pending"))
  defp apply_filter(users, "active"), do: Enum.filter(users, &(&1.status == "active"))

  defp user_status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp user_status_class("active"), do: "bg-green-100 text-green-800"
  defp user_status_class(_), do: "bg-gray-100 text-gray-800"

  defp user_status_label("pending"), do: "Pending"
  defp user_status_label("active"), do: "Active"
  defp user_status_label(_), do: "Unknown"
end
