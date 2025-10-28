defmodule TrialAppWeb.AdminLive.PositionManagement do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:positions, [])
     |> assign(:show_form, false)
     |> assign(:form_data, %{title: "", description: "", salary_range: ""})
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
                  <span class="text-4xl">💼</span>
                  Position Management
                </h1>
                <p class="text-gray-600 mt-2">Manage job positions and salary ranges</p>
              </div>
              <button
                phx-click="new_position"
                class="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl font-semibold"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                Add Position
              </button>
            </div>
          </div>
        </div>

        <!-- Content Area -->
        <div class="p-8">
          <div class="max-w-7xl mx-auto">
            <!-- Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
              <div class="bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-indigo-100 text-sm font-semibold">Total Positions</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@positions) %></p>
                  </div>
                  <div class="text-5xl opacity-50">💼</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-blue-100 text-sm font-semibold">Active</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@positions) %></p>
                  </div>
                  <div class="text-5xl opacity-50">✅</div>
                </div>
              </div>

              <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white shadow-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-green-100 text-sm font-semibold">This Month</p>
                    <p class="text-4xl font-bold mt-2"><%= length(@positions) %></p>
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
                  placeholder="Search positions..."
                  class="w-full pl-10 pr-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                />
              </div>
            </div>

            <!-- Positions Grid/List -->
            <%= if Enum.empty?(@positions) do %>
              <!-- Empty State -->
              <div class="bg-white rounded-2xl shadow-sm p-16 text-center">
                <div class="max-w-md mx-auto">
                  <div class="text-7xl mb-6">💼</div>
                  <h3 class="text-2xl font-bold text-gray-900 mb-2">No Positions Yet</h3>
                  <p class="text-gray-600 mb-8">
                    Get started by creating your first job position.
                  </p>
                  <button
                    phx-click="new_position"
                    class="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg font-semibold"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                    </svg>
                    Create First Position
                  </button>
                </div>
              </div>
            <% else %>
              <!-- Positions Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for position <- @positions do %>
                  <div class="bg-white rounded-xl shadow-sm hover:shadow-lg transition-all border-2 border-gray-100 hover:border-indigo-200 p-6 group">
                    <div class="flex items-start justify-between mb-4">
                      <div class="flex items-center gap-3">
                        <div class="w-12 h-12 bg-gradient-to-br from-indigo-500 to-purple-500 rounded-xl flex items-center justify-center text-2xl">
                          💼
                        </div>
                        <div>
                          <h3 class="font-bold text-lg text-gray-900 group-hover:text-indigo-600 transition-colors">
                            <%= position.title %>
                          </h3>
                          <span class="text-sm text-gray-500">Active</span>
                        </div>
                      </div>
                      <div class="flex gap-1">
                        <button
                          phx-click="edit_position"
                          phx-value-id={position.id}
                          class="p-2 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                          title="Edit Position"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                          </svg>
                        </button>
                        <button
                          phx-click="show_delete_modal"
                          phx-value-id={position.id}
                          class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete Position"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                          </svg>
                        </button>
                      </div>
                    </div>

                    <p class="text-gray-600 text-sm mb-4 line-clamp-2">
                      <%= if position.description && position.description != "" do %>
                        <%= position.description %>
                      <% else %>
                        <span class="text-gray-400 italic">No description provided</span>
                      <% end %>
                    </p>

                    <div class="flex items-center gap-4 text-sm text-gray-500 pt-4 border-t border-gray-100">
                      <div class="flex items-center gap-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                        </svg>
                        <span><%= position.salary_range %></span>
                      </div>
                      <div class="flex items-center gap-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                        </svg>
                        <span>0 Employees</span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </main>

      <!-- Add/Edit Position Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl transform transition-all">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-500 rounded-xl flex items-center justify-center text-xl">
                  💼
                </div>
                <h2 class="text-2xl font-bold text-gray-900">
                  <%= if @editing_id, do: "Edit Position", else: "Add New Position" %>
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
            <form phx-submit="save_position" phx-change="update_form" class="p-6 space-y-6">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Position Title *
                </label>
                <input
                  type="text"
                  name="title"
                  value={@form_data.title}
                  placeholder="e.g., Senior Developer, HR Manager"
                  class={[
                    "w-full px-4 py-3 border-2 rounded-xl outline-none transition-all",
                    if(@errors[:title], do: "border-red-300 bg-red-50 focus:ring-2 focus:ring-red-500", else: "border-gray-300 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500")
                  ]}
                  required
                />
                <%= if @errors[:title] do %>
                  <p class="mt-2 text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                    </svg>
                    <%= @errors[:title] %>
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Salary Range
                </label>
                <input
                  type="text"
                  name="salary_range"
                  value={@form_data.salary_range}
                  placeholder="e.g., $80k - $120k, $100k - $150k"
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                />
                <p class="mt-2 text-sm text-gray-500">Optional: Specify the salary range for this position</p>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Description
                </label>
                <textarea
                  name="description"
                  rows="4"
                  placeholder="Brief description of this position's responsibilities and requirements..."
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all resize-none"
                ><%= @form_data.description %></textarea>
                <p class="mt-2 text-sm text-gray-500">Optional: Add a description to help identify this position</p>
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
                  class="px-6 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg font-semibold"
                >
                  <%= if @editing_id, do: "Update Position", else: "Create Position" %>
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

              <h3 class="text-xl font-bold text-gray-900 mb-2">Delete Position</h3>
              <p class="text-gray-600 mb-6">
                Are you sure you want to delete this position? This action cannot be undone.
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
                  Delete Position
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("new_position", _params, socket) do
    {:noreply, assign(socket,
      show_form: true,
      editing_id: nil,
      form_data: %{title: "", description: "", salary_range: ""},
      errors: %{}
    )}
  end

  def handle_event("edit_position", %{"id" => id}, socket) do
    position = Enum.find(socket.assigns.positions, &(&1.id == String.to_integer(id)))
    if position do
      {:noreply, assign(socket,
        show_form: true,
        editing_id: String.to_integer(id),
        form_data: %{
          title: position.title,
          description: position.description || "",
          salary_range: position.salary_range || ""
        },
        errors: %{}
      )}
    else
      {:noreply, put_flash(socket, :error, "Position not found")}
    end
  end

  def handle_event("hide_modal", _params, socket) do
    {:noreply, assign(socket,
      show_form: false,
      editing_id: nil,
      form_data: %{title: "", description: "", salary_range: ""},
      errors: %{}
    )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  def handle_event("update_form", params, socket) do
    form_data = case params do
      %{"title" => title, "description" => description, "salary_range" => salary_range} ->
        %{title: title, description: description, salary_range: salary_range}
      %{"value" => value} when is_binary(value) ->
        parse_form_data(value)
      _ ->
        socket.assigns.form_data
    end

    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("save_position", params, socket) do
    {title, description, salary_range} = case params do
      %{"title" => t, "description" => d, "salary_range" => sr} ->
        {t, d, sr}
      %{"value" => value} when is_binary(value) ->
        parse_form_values(value)
      _ ->
        {"", "", ""}
    end

    errors = %{}
    errors = if String.trim(title) == "", do: Map.put(errors, :title, "Position title is required"), else: errors

    if map_size(errors) == 0 do
      if socket.assigns.editing_id do
        # Update existing position
        updated_positions = Enum.map(socket.assigns.positions, fn pos ->
          if pos.id == socket.assigns.editing_id do
            %{pos | title: title, description: description, salary_range: salary_range}
          else
            pos
          end
        end)

        {:noreply,
          socket
          |> assign(show_form: false, editing_id: nil, form_data: %{title: "", description: "", salary_range: ""}, errors: %{})
          |> assign(positions: updated_positions)
          |> put_flash(:info, "✅ Position '#{title}' updated successfully!")
        }
      else
        # Create new position
        new_position = %{
          id: :rand.uniform(100_000),
          title: title,
          description: description,
          salary_range: salary_range
        }
        {:noreply,
          socket
          |> assign(show_form: false, form_data: %{title: "", description: "", salary_range: ""}, errors: %{})
          |> assign(positions: [new_position | socket.assigns.positions])
          |> put_flash(:info, "✅ Position '#{title}' created successfully!")
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
    position_id = String.to_integer(id)
    position = Enum.find(socket.assigns.positions, &(&1.id == position_id))

    if position do
      updated_positions = Enum.reject(socket.assigns.positions, &(&1.id == position_id))

      {:noreply,
        socket
        |> assign(positions: updated_positions, show_delete_modal: false, deleting_id: nil)
        |> put_flash(:info, "🗑️ Position '#{position.title}' deleted successfully!")
      }
    else
      {:noreply,
        socket
        |> assign(show_delete_modal: false, deleting_id: nil)
        |> put_flash(:error, "Position not found")
      }
    end
  end

  defp parse_form_data(form_string) when is_binary(form_string) do
    form_string
    |> String.split("&")
    |> Enum.reduce(%{title: "", description: "", salary_range: ""}, fn pair, acc ->
      case String.split(pair, "=") do
        ["title", value] -> Map.put(acc, :title, URI.decode(value))
        ["description", value] -> Map.put(acc, :description, URI.decode(value))
        ["salary_range", value] -> Map.put(acc, :salary_range, URI.decode(value))
        _ -> acc
      end
    end)
  end

  defp parse_form_data(_), do: %{title: "", description: "", salary_range: ""}

  defp parse_form_values(form_string) when is_binary(form_string) do
    data = parse_form_data(form_string)
    {data[:title] || "", data[:description] || "", data[:salary_range] || ""}
  end

  defp parse_form_values(_), do: {"", "", ""}
end
