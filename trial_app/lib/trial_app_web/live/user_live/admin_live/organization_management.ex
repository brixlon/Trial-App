defmodule TrialAppWeb.AdminLive.OrganizationManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Organizations

  def mount(_params, _session, socket) do
    organizations = Organizations.list_organizations()

    {:ok,
     socket
     |> assign(:organizations, organizations)
     |> assign(:show_form, false)
     |> assign(:form_data, %{name: "", description: "", email: "", phone: "", address: ""})
     |> assign(:errors, %{})
     |> assign(:search_query, "")
     |> assign(:editing_id, nil)
     |> assign(:show_delete_modal, false)
     |> assign(:deleting_id, nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-50">
      <!-- Sidebar -->
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <!-- Main Content -->
      <main class="flex-1 overflow-y-auto ml-64">
        <!-- Header Bar -->
        <div class="bg-white border-b border-gray-200 sticky top-0 z-10">
          <div class="px-8 py-6">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-gray-900 flex items-center gap-3">
                  <span class="text-4xl">🏢</span>
                  Organization Management
                </h1>
                <p class="text-gray-600 mt-2">Manage your company organizations</p>
              </div>
              <button
                phx-click="new_organization"
                class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg hover:shadow-xl font-semibold"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                Add Organization
              </button>
            </div>
          </div>
        </div>

        <!-- Content Area -->
        <div class="p-8">
          <div class="max-w-7xl mx-auto">
            <!-- Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
              <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-blue-100 text-sm font-semibold">Total Organizations</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@organizations) %></p>
                  </div>
                  <div class="text-5xl opacity-50">🏢</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-green-100 text-sm font-semibold">Active</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@organizations) %></p>
                  </div>
                  <div class="text-5xl opacity-50">✅</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-purple-100 text-sm font-semibold">This Month</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@organizations) %></p>
                  </div>
                  <div class="text-5xl opacity-50">📊</div>
                </div>
              </div>
            </div>

            <!-- Search Bar -->
            <div class="bg-white rounded-xl shadow-sm p-4 mb-6">
              <div class="relative">
                <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <input
                  type="text"
                  phx-change="search"
                  name="query"
                  value={@search_query}
                  placeholder="Search organizations..."
                  class="w-full pl-10 pr-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                />
              </div>
            </div>

            <!-- Organizations Grid -->
            <%= if Enum.empty?(@organizations) do %>
              <!-- Empty State -->
              <div class="bg-white rounded-2xl shadow-sm p-16 text-center">
                <div class="max-w-md mx-auto">
                  <div class="text-7xl mb-6">🏢</div>
                  <h3 class="text-2xl font-bold text-gray-900 mb-2">No Organizations Yet</h3>
                  <p class="text-gray-600 mb-8">
                    Get started by creating your first organization to manage your company structure.
                  </p>
                  <button
                    phx-click="new_organization"
                    class="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg font-semibold"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                    </svg>
                    Create First Organization
                  </button>
                </div>
              </div>
            <% else %>
              <!-- Organizations Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for org <- @organizations do %>
                  <div class="bg-white rounded-xl shadow-sm hover:shadow-lg transition-all border-2 border-gray-100 hover:border-blue-200 p-6 group">
                    <div class="flex items-start justify-between mb-4">
                      <div class="flex items-center gap-3">
                        <div class="w-12 h-12 bg-gradient-to-br from-blue-500 to-indigo-500 rounded-xl flex items-center justify-center text-2xl">
                          🏢
                        </div>
                        <div>
                          <h3 class="font-bold text-lg text-gray-900 group-hover:text-blue-600 transition-colors">
                            <%= org.name %>
                          </h3>
                          <span class="text-sm text-gray-500">Active</span>
                        </div>
                      </div>
                      <div class="flex gap-1">
                        <button
                          phx-click="edit_organization"
                          phx-value-id={org.id}
                          class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                          title="Edit Organization"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                          </svg>
                        </button>
                        <button
                          phx-click="show_delete_modal"
                          phx-value-id={org.id}
                          class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete Organization"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                          </svg>
                        </button>
                      </div>
                    </div>

                    <p class="text-gray-600 text-sm mb-4 line-clamp-2">
                      <%= if org.description && org.description != "" do %>
                        <%= org.description %>
                      <% else %>
                        <span class="text-gray-400 italic">No description provided</span>
                      <% end %>
                    </p>

                    <div class="space-y-2 text-sm text-gray-500">
                      <%= if org.email do %>
                        <div class="flex items-center gap-2">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                          </svg>
                          <span><%= org.email %></span>
                        </div>
                      <% end %>
                      <%= if org.phone do %>
                        <div class="flex items-center gap-2">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                          </svg>
                          <span><%= org.phone %></span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </main>

      <!-- Add/Edit Organization Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl transform transition-all">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-indigo-500 rounded-xl flex items-center justify-center text-xl">
                  🏢
                </div>
                <h2 class="text-2xl font-bold text-gray-900">
                  <%= if @editing_id, do: "Edit Organization", else: "Add New Organization" %>
                </h2>
              </div>
              <button
                phx-click="hide_modal"
                class="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Modal Body -->
            <form phx-submit="save_organization" class="p-6 space-y-4">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Organization Name *
                </label>
                <input
                  type="text"
                  name="name"
                  value={@form_data.name}
                  placeholder="e.g., Tech Corp, Innovate Ltd"
                  class={[
                    "w-full px-4 py-3 border-2 rounded-xl outline-none transition-all",
                    if(@errors[:name], do: "border-red-300 bg-red-50 focus:ring-2 focus:ring-red-500", else: "border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500")
                  ]}
                  required
                />
                <%= if @errors[:name] do %>
                  <p class="mt-2 text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                    </svg>
                    <%= @errors[:name] %>
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Description
                </label>
                <textarea
                  name="description"
                  rows="3"
                  placeholder="Brief description of the organization..."
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all resize-none"
                ><%= @form_data.description %></textarea>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">
                    Email
                  </label>
                  <input
                    type="email"
                    name="email"
                    value={@form_data.email}
                    placeholder="contact@company.com"
                    class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                  />
                </div>

                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">
                    Phone
                  </label>
                  <input
                    type="tel"
                    name="phone"
                    value={@form_data.phone}
                    placeholder="+1234567890"
                    class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                  />
                </div>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Address
                </label>
                <textarea
                  name="address"
                  rows="2"
                  placeholder="123 Business St, City, Country"
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all resize-none"
                ><%= @form_data.address %></textarea>
              </div>

              <!-- Modal Footer -->
              <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="hide_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl hover:from-blue-700 hover:to-indigo-700 transition-all shadow-lg font-semibold"
                >
                  <%= if @editing_id, do: "Update Organization", else: "Create Organization" %>
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <!-- Delete Confirmation Modal -->
      <%= if @show_delete_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-md shadow-2xl transform transition-all">
            <div class="p-6 text-center">
              <!-- Warning Icon -->
              <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.35 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                </svg>
              </div>

              <h3 class="text-xl font-bold text-gray-900 mb-2">Delete Organization</h3>
              <p class="text-gray-600 mb-6">
                Are you sure you want to delete this organization? This action cannot be undone and will also delete all associated departments, teams, and employees.
              </p>

              <div class="flex justify-center gap-3">
                <button
                  phx-click="hide_delete_modal"
                  class="px-6 py-3 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl font-semibold transition-colors"
                >
                  Cancel
                </button>
                <button
                  phx-click="confirm_delete"
                  phx-value-id={@deleting_id}
                  class="px-6 py-3 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-all shadow-lg font-semibold"
                >
                  Delete Organization
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("new_organization", _params, socket) do
    {:noreply, assign(socket,
      show_form: true,
      editing_id: nil,
      form_data: %{name: "", description: "", email: "", phone: "", address: ""},
      errors: %{}
    )}
  end

  def handle_event("edit_organization", %{"id" => id}, socket) do
    organization = Organizations.get_organization!(id)

    {:noreply, assign(socket,
      show_form: true,
      editing_id: String.to_integer(id),
      form_data: %{
        name: organization.name,
        description: organization.description || "",
        email: organization.email || "",
        phone: organization.phone || "",
        address: organization.address || ""
      },
      errors: %{}
    )}
  end

  def handle_event("hide_modal", _params, socket) do
    {:noreply, assign(socket,
      show_form: false,
      editing_id: nil,
      form_data: %{name: "", description: "", email: "", phone: "", address: ""},
      errors: %{}
    )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  def handle_event("save_organization", params, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      email: params["email"],
      phone: params["phone"],
      address: params["address"]
    }

    # Validate required fields
    errors = %{}
    errors = if String.trim(attrs.name) == "", do: Map.put(errors, :name, "Organization name is required"), else: errors

    if map_size(errors) == 0 do
      result = if socket.assigns.editing_id do
        organization = Organizations.get_organization!(socket.assigns.editing_id)
        Organizations.update_organization(organization, attrs)
      else
        Organizations.create_organization(attrs)
      end

      case result do
        {:ok, organization} ->
          organizations = Organizations.list_organizations()

          {:noreply,
            socket
            |> assign(show_form: false, editing_id: nil, form_data: %{name: "", description: "", email: "", phone: "", address: ""}, errors: %{})
            |> assign(organizations: organizations)
            |> put_flash(:info, if(socket.assigns.editing_id, do: "✅ Organization '#{organization.name}' updated successfully!", else: "✅ Organization '#{organization.name}' created successfully!"))
          }

        {:error, changeset} ->
          error_message =
            changeset.errors
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")

          {:noreply,
            socket
            |> assign(errors: %{name: error_message})
            |> put_flash(:error, "Failed to save organization: #{error_message}")
          }
      end
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket,
      show_delete_modal: true,
      deleting_id: String.to_integer(id)
    )}
  end

  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket,
      show_delete_modal: false,
      deleting_id: nil
    )}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    organization_id = String.to_integer(id)
    organization = Organizations.get_organization!(organization_id)

    case Organizations.delete_organization(organization) do
      {:ok, _} ->
        organizations = Organizations.list_organizations()

        {:noreply,
          socket
          |> assign(organizations: organizations, show_delete_modal: false, deleting_id: nil)
          |> put_flash(:info, "🗑️ Organization '#{organization.name}' deleted successfully!")
        }

      {:error, _changeset} ->
        {:noreply,
          socket
          |> assign(show_delete_modal: false, deleting_id: nil)
          |> put_flash(:error, "Failed to delete organization")
        }
    end
  end
end
