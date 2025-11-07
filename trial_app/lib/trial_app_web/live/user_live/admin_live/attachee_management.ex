defmodule TrialAppWeb.AdminLive.AttacheeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Repo, Eams, Orgs, Accounts}
  alias TrialApp.Eams.Attachee

  # Mount initial assigns
  def mount(_params, _session, socket) do
    organizations = Orgs.list_organizations()
    users = Accounts.list_users()
    attachees = Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})

    # Create a changeset for a new attachee
    changeset = Attachee.changeset(%Attachee{}, %{})

    {:ok,
     assign(socket,
       form: to_form(changeset),
       organizations: organizations,
       departments: [],
       programs: [],
       users: users,
       attachees: attachees,
       show_form: false,
       editing_attachee: nil,
       show_view_modal: false,
       viewing_attachee: nil,
       filter_status: "all",
       current_scope: socket.assigns[:current_scope] || %{}
     )}
  end

  # Render template
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={@current_scope} />

      <div class="ml-64 p-8">
        <div class="space-y-8">
          <!-- Header -->
          <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
            <div>
              <h1 class="text-3xl font-bold text-[#3B3B98]">Attachee Management</h1>
              <p class="text-sm text-gray-500 mt-1">Manage attachees, enrollments, and assignments</p>
            </div>
            <button
              phx-click="toggle_form"
              class="px-4 py-2 rounded-lg bg-[#6C63FF] text-white hover:bg-[#5A52E8] transition flex items-center gap-2"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= if @show_form do %>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                <% else %>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                <% end %>
              </svg>
              <%= if @show_form, do: "Close Form", else: "Add Attachee" %>
            </button>
          </div>

          <!-- Filter Tabs -->
          <div class="flex gap-2 border-b border-gray-200">
            <%= for {label, status, count} <- [
                  {"All", "all", length(@attachees)},
                  {"Active", "active", Enum.count(@attachees, &(&1.status == "active"))},
                  {"Inactive", "inactive", Enum.count(@attachees, &(&1.status == "inactive"))},
                  {"Completed", "completed", Enum.count(@attachees, &(&1.status == "completed"))}
                ] do %>
              <button
                phx-click="filter"
                phx-value-status={status}
                class={"px-5 py-2.5 text-sm font-medium border-b-2 transition #{if @filter_status == status, do: "border-[#6C63FF] text-[#6C63FF]", else: "border-transparent text-gray-500 hover:text-gray-700"}"}
              >
                <%= label %> <span class="ml-1 text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full"><%= count %></span>
              </button>
            <% end %>
          </div>

          <!-- Stats Cards -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="bg-gradient-to-br from-[#6C63FF] to-[#5A52E8] rounded-2xl p-5 text-white shadow-lg">
              <div class="flex items-center justify-between mb-2">
                <div class="w-12 h-12 rounded-xl bg-white/20 flex items-center justify-center">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                  </svg>
                </div>
                <span class="text-2xl font-bold"><%= length(@attachees) %></span>
              </div>
              <p class="text-sm opacity-90">Total Attachees</p>
            </div>

            <div class="bg-gradient-to-br from-emerald-500 to-emerald-600 rounded-2xl p-5 text-white shadow-lg">
              <div class="flex items-center justify-between mb-2">
                <div class="w-12 h-12 rounded-xl bg-white/20 flex items-center justify-center">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                </div>
                <span class="text-2xl font-bold"><%= Enum.count(@attachees, &(&1.status == "active")) %></span>
              </div>
              <p class="text-sm opacity-90">Active</p>
            </div>

            <div class="bg-gradient-to-br from-amber-500 to-amber-600 rounded-2xl p-5 text-white shadow-lg">
              <div class="flex items-center justify-between mb-2">
                <div class="w-12 h-12 rounded-xl bg-white/20 flex items-center justify-center">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
                <span class="text-2xl font-bold"><%= Enum.count(@attachees, &(&1.status == "inactive")) %></span>
              </div>
              <p class="text-sm opacity-90">Inactive</p>
            </div>

            <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-5 text-white shadow-lg">
              <div class="flex items-center justify-between mb-2">
                <div class="w-12 h-12 rounded-xl bg-white/20 flex items-center justify-center">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
                <span class="text-2xl font-bold"><%= Enum.count(@attachees, &(&1.status == "completed")) %></span>
              </div>
              <p class="text-sm opacity-90">Completed</p>
            </div>
          </div>

          <!-- Attachee Form -->
          <%= if @show_form do %>
            <div class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
              <div class="bg-white rounded-2xl w-full max-w-3xl shadow-2xl max-h-[90vh] overflow-y-auto">
                <div class="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white">
                  <div>
                    <h2 class="text-2xl font-bold text-[#3B3B98]">
                      <%= if @editing_attachee, do: "Edit Attachee", else: "Add New Attachee" %>
                    </h2>
                    <p class="text-sm text-gray-500 mt-1">Fill in the details below</p>
                  </div>
                  <button phx-click="toggle_form" class="p-2 hover:bg-gray-100 rounded-lg">
                    <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>

                <div class="p-6">
                  <.form for={@form} phx-submit="save" phx-change="update">
                    <div class="space-y-5">
                      <!-- User Selection -->
                      <div class="space-y-2">
                        <label class="block text-sm font-semibold text-gray-700">
                          User <span class="text-red-500">*</span>
                        </label>
                        <select
                          name="attachee[user_id]"
                          class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                        >
                          <option value="">Select User</option>
                          <%= for user <- @users do %>
                            <option value={user.id} selected={@form.params["user_id"] == to_string(user.id)}>
                              <%= user.username %> (<%= user.email %>)
                            </option>
                          <% end %>
                        </select>
                        <%= if @form[:user_id].errors != [] do %>
                          <p class="text-sm text-red-600"><%= translate_errors(@form[:user_id].errors) %></p>
                        <% end %>
                      </div>

                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <!-- Organization -->
                        <div class="space-y-2">
                          <label class="block text-sm font-semibold text-gray-700">
                            Organization <span class="text-red-500">*</span>
                          </label>
                          <select
                            name="attachee[organization_id]"
                            phx-change="update"
                            class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                          >
                            <option value="">Select Organization</option>
                            <%= for org <- @organizations do %>
                              <option value={org.id} selected={@form.params["organization_id"] == to_string(org.id)}>
                                <%= org.name %>
                              </option>
                            <% end %>
                          </select>
                          <%= if @form[:organization_id].errors != [] do %>
                            <p class="text-sm text-red-600"><%= translate_errors(@form[:organization_id].errors) %></p>
                          <% end %>
                        </div>

                        <!-- Department -->
                        <div class="space-y-2">
                          <label class="block text-sm font-semibold text-gray-700">
                            Department <span class="text-red-500">*</span>
                          </label>
                          <select
                            name="attachee[department_id]"
                            phx-change="update"
                            class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                          >
                            <option value=""><%= if Enum.empty?(@departments), do: "Select organization first", else: "Select Department" %></option>
                            <%= for dept <- @departments do %>
                              <option value={dept.id} selected={@form.params["department_id"] == to_string(dept.id)}>
                                <%= dept.name %>
                              </option>
                            <% end %>
                          </select>
                          <%= if @form[:department_id].errors != [] do %>
                            <p class="text-sm text-red-600"><%= translate_errors(@form[:department_id].errors) %></p>
                          <% end %>
                        </div>
                      </div>

                      <!-- Program -->
                      <div class="space-y-2">
                        <label class="block text-sm font-semibold text-gray-700">Program</label>
                        <select
                          name="attachee[program_id]"
                          class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                        >
                          <option value=""><%= if Enum.empty?(@programs), do: "Select department first", else: "Select Program (Optional)" %></option>
                          <%= for prog <- @programs do %>
                            <option value={prog.id} selected={@form.params["program_id"] == to_string(prog.id)}>
                              <%= prog.name %>
                            </option>
                          <% end %>
                        </select>
                      </div>

                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <!-- Start Date -->
                        <div class="space-y-2">
                          <label class="block text-sm font-semibold text-gray-700">
                            Start Date <span class="text-red-500">*</span>
                          </label>
                          <input
                            type="date"
                            name="attachee[starts_on]"
                            value={@form.params["starts_on"]}
                            class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                          />
                          <%= if @form[:starts_on].errors != [] do %>
                            <p class="text-sm text-red-600"><%= translate_errors(@form[:starts_on].errors) %></p>
                          <% end %>
                        </div>

                        <!-- End Date -->
                        <div class="space-y-2">
                          <label class="block text-sm font-semibold text-gray-700">End Date</label>
                          <input
                            type="date"
                            name="attachee[ends_on]"
                            value={@form.params["ends_on"]}
                            class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                          />
                          <%= if @form[:ends_on].errors != [] do %>
                            <p class="text-sm text-red-600"><%= translate_errors(@form[:ends_on].errors) %></p>
                          <% end %>
                        </div>
                      </div>

                      <%= if @editing_attachee do %>
                        <div class="space-y-2">
                          <label class="block text-sm font-semibold text-gray-700">Status</label>
                          <select
                            name="attachee[status]"
                            class="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-[#6C63FF] focus:border-transparent transition-all"
                          >
                            <%= for status <- ["active", "inactive", "completed"] do %>
                              <option value={status} selected={status == @form.params["status"]}>
                                <%= String.capitalize(status) %>
                              </option>
                            <% end %>
                          </select>
                        </div>
                      <% end %>
                    </div>

                    <div class="flex items-center justify-end gap-3 mt-6 pt-6 border-t border-gray-200">
                      <button
                        type="button"
                        phx-click="toggle_form"
                        class="px-6 py-2.5 rounded-lg border border-gray-300 text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                      >
                        Cancel
                      </button>
                      <button
                        type="submit"
                        class="px-6 py-2.5 rounded-lg bg-[#6C63FF] text-white font-medium hover:bg-[#5A52E8] transition-colors"
                      >
                        <%= if @editing_attachee, do: "Update Attachee", else: "Create Attachee" %>
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Attachees Table -->
          <div class="bg-white shadow-lg rounded-2xl border border-gray-100 overflow-hidden">
            <%= if filtered_attachees(@attachees, @filter_status) == [] do %>
              <div class="py-12 text-center">
                <div class="flex flex-col items-center gap-3">
                  <div class="w-20 h-20 rounded-full bg-[#F0EEFF] flex items-center justify-center">
                    <svg class="w-10 h-10 text-[#6C63FF]/60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                    </svg>
                  </div>
                  <p class="font-semibold text-gray-700 text-lg">No attachees found</p>
                  <p class="text-sm text-gray-500">Get started by adding your first attachee</p>
                  <button phx-click="toggle_form" class="mt-2 px-5 py-2.5 rounded-lg bg-[#6C63FF] text-white font-medium hover:bg-[#5A52E8]">
                    Add Attachee
                  </button>
                </div>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full text-left">
                  <thead class="bg-[#6C63FF] text-white">
                    <tr>
                      <th class="px-6 py-4 text-sm font-semibold">USER</th>
                      <th class="px-6 py-4 text-sm font-semibold">ORGANIZATION</th>
                      <th class="px-6 py-4 text-sm font-semibold">DEPARTMENT</th>
                      <th class="px-6 py-4 text-sm font-semibold">PROGRAMS</th>
                      <th class="px-6 py-4 text-sm font-semibold">DURATION</th>
                      <th class="px-6 py-4 text-sm font-semibold">STATUS</th>
                      <th class="px-6 py-4 text-sm font-semibold text-right">ACTIONS</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-100">
                    <%= for attachee <- filtered_attachees(@attachees, @filter_status) do %>
                      <tr class="hover:bg-[#F8F8FF] transition group">
                        <td class="px-6 py-4">
                          <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-full bg-gradient-to-br from-[#6C63FF] to-[#5A52E8] flex items-center justify-center text-white font-bold text-sm shadow-md">
                              <%= get_initials(attachee.user.username) %>
                            </div>
                            <div>
                              <span class="text-gray-800 font-semibold block"><%= attachee.user.username %></span>
                              <span class="text-xs text-gray-500"><%= attachee.user.email %></span>
                            </div>
                          </div>
                        </td>
                        <td class="px-6 py-4">
                          <span class="text-sm text-gray-700"><%= attachee.organization.name %></span>
                        </td>
                        <td class="px-6 py-4">
                          <span class="inline-flex items-center px-3 py-1.5 text-sm rounded-full bg-purple-100 text-purple-800 font-medium">
                            <%= attachee.department.name %>
                          </span>
                        </td>
                        <td class="px-6 py-4">
                          <%= if Ecto.assoc_loaded?(attachee.programs) and attachee.programs != [] do %>
                            <div class="flex flex-wrap gap-1">
                              <%= for program <- Enum.take(attachee.programs, 2) do %>
                                <span class="inline-flex items-center px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800 font-medium">
                                  <%= program.name %>
                                </span>
                              <% end %>
                              <%= if length(attachee.programs) > 2 do %>
                                <span class="inline-flex items-center px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-600 font-medium">
                                  +<%= length(attachee.programs) - 2 %>
                                </span>
                              <% end %>
                            </div>
                          <% else %>
                            <span class="text-sm text-gray-400">No programs</span>
                          <% end %>
                        </td>
                        <td class="px-6 py-4">
                          <div class="text-sm text-gray-600">
                            <%= if attachee.starts_on do %>
                              <div class="flex items-center gap-1.5">
                                <svg class="w-3.5 h-3.5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                                </svg>
                                <%= Calendar.strftime(attachee.starts_on, "%b %d, %Y") %>
                              </div>
                              <%= if attachee.ends_on do %>
                                <div class="text-xs text-gray-500 mt-1">
                                  to <%= Calendar.strftime(attachee.ends_on, "%b %d, %Y") %>
                                </div>
                              <% end %>
                            <% else %>
                              <span class="text-gray-400">Not set</span>
                            <% end %>
                          </div>
                        </td>
                        <td class="px-6 py-4">
                          <span class={"inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium #{status_color(attachee.status)}"}>
                            <span class="w-1.5 h-1.5 rounded-full bg-current"></span>
                            <%= String.capitalize(attachee.status) %>
                          </span>
                        </td>
                        <td class="px-6 py-4">
                          <div class="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition">
                            <button phx-click="view_attachee" phx-value-id={attachee.id} class="p-2 hover:bg-[#E8E7FF] rounded-lg" title="View">
                              <svg class="w-4 h-4 text-[#6C63FF]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                              </svg>
                            </button>
                            <button phx-click="edit_attachee" phx-value-id={attachee.id} class="p-2 hover:bg-[#E8E7FF] rounded-lg" title="Edit">
                              <svg class="w-4 h-4 text-[#6C63FF]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                              </svg>
                            </button>
                            <button phx-click="delete_attachee" phx-value-id={attachee.id} data-confirm="Delete this attachee?" class="p-2 hover:bg-red-50 rounded-lg" title="Delete">
                              <svg class="w-4 h-4 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- VIEW MODAL -->
      <%= if @show_view_modal && @viewing_attachee do %>
        <div class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-2xl w-full max-w-3xl shadow-2xl">
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <div class="flex items-center gap-4">
                <div class="w-16 h-16 rounded-full bg-gradient-to-br from-[#6C63FF] to-[#5A52E8] flex items-center justify-center text-white font-bold text-2xl shadow-lg">
                  <%= get_initials(@viewing_attachee.user.username) %>
                </div>
                <div>
                  <h2 class="text-2xl font-bold text-[#3B3B98]"><%= @viewing_attachee.user.username %></h2>
                  <p class="text-sm text-gray-500 mt-1"><%= @viewing_attachee.user.email %></p>
                </div>
              </div>
              <button phx-click="close_view" class="p-2 hover:bg-gray-100 rounded-lg">
                <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="p-6 space-y-6">
              <div class="flex items-center gap-3">
                <span class="text-sm font-semibold text-gray-500">Status:</span>
                <span class={"inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium #{status_color(@viewing_attachee.status)}"}>
                  <span class="w-1.5 h-1.5 rounded-full bg-current"></span>
                  <%= String.capitalize(@viewing_attachee.status) %>
                </span>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="bg-gray-50 rounded-xl p-4">
                  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Organization</p>
                  <p class="text-lg font-semibold text-gray-800"><%= @viewing_attachee.organization.name %></p>
                </div>
                <div class="bg-gray-50 rounded-xl p-4">
                  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Department</p>
                  <p class="text-lg font-semibold text-gray-800"><%= @viewing_attachee.department.name %></p>
                </div>
                <div class="bg-gray-50 rounded-xl p-4">
                  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Start Date</p>
                  <p class="text-lg font-semibold text-gray-800">
                    <%= if @viewing_attachee.starts_on, do: Calendar.strftime(@viewing_attachee.starts_on, "%B %d, %Y"), else: "Not set" %>
                  </p>
                </div>
                <div class="bg-gray-50 rounded-xl p-4">
                  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">End Date</p>
                  <p class="text-lg font-semibold text-gray-800">
                    <%= if @viewing_attachee.ends_on, do: Calendar.strftime(@viewing_attachee.ends_on, "%B %d, %Y"), else: "Not set" %>
                  </p>
                </div>
              </div>

              <%= if Ecto.assoc_loaded?(@viewing_attachee.programs) and @viewing_attachee.programs != [] do %>
                <div>
                  <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Enrolled Programs</p>
                  <div class="flex flex-wrap gap-2">
                    <%= for program <- @viewing_attachee.programs do %>
                      <span class="inline-flex items-center px-4 py-2 text-sm rounded-lg bg-blue-100 text-blue-800 font-medium">
                        <%= program.name %>
                      </span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
            <div class="flex justify-end gap-3 p-6 border-t border-gray-200">
              <button phx-click="edit_attachee" phx-value-id={@viewing_attachee.id} class="px-6 py-2.5 rounded-lg border border-[#6C63FF] text-[#6C63FF] font-medium hover:bg-[#F0EEFF]">
                Edit Attachee
              </button>
              <button phx-click="close_view" class="px-6 py-2.5 rounded-lg bg-[#6C63FF] text-white font-medium hover:bg-[#5A52E8]">
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Toggle form visibility
  def handle_event("toggle_form", _params, socket) do
    # Reset form when toggling
    changeset = Attachee.changeset(%Attachee{}, %{})
    {:noreply,
     socket
     |> assign(:show_form, !socket.assigns.show_form)
     |> assign(:editing_attachee, nil)
     |> assign(:form, to_form(changeset))
     |> assign(:departments, [])
     |> assign(:programs, [])}
  end

  # Handle filter
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  # View attachee
  def handle_event("view_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id) |> Repo.preload([:user, :organization, :department, :programs])
    {:noreply,
     socket
     |> assign(:viewing_attachee, attachee)
     |> assign(:show_view_modal, true)}
  end

  # Close view modal
  def handle_event("close_view", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_view_modal, false)
     |> assign(:viewing_attachee, nil)}
  end

  # Edit attachee
  def handle_event("edit_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id) |> Repo.preload([:user, :organization, :department, :programs])

    # Load departments for the organization
    departments = if attachee.organization_id do
      Orgs.list_departments_by_org(attachee.organization_id)
    else
      []
    end

    # Load programs for the department
    programs = if attachee.department_id do
      Eams.list_programs_by_department(attachee.department_id)
    else
      []
    end

    # Get the first program ID if any programs are enrolled
    program_id = if Ecto.assoc_loaded?(attachee.programs) and attachee.programs != [] do
      hd(attachee.programs).id
    else
      nil
    end

    form_data = %{
      "user_id" => to_string(attachee.user_id),
      "organization_id" => to_string(attachee.organization_id),
      "department_id" => to_string(attachee.department_id),
      "program_id" => if(program_id, do: to_string(program_id), else: ""),
      "starts_on" => if(attachee.starts_on, do: Date.to_iso8601(attachee.starts_on), else: ""),
      "ends_on" => if(attachee.ends_on, do: Date.to_iso8601(attachee.ends_on), else: ""),
      "status" => attachee.status
    }

    changeset = Attachee.changeset(attachee, form_data)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:show_view_modal, false)
     |> assign(:editing_attachee, attachee)
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  # Delete attachee
  def handle_event("delete_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id)

    case Eams.delete_attachee(attachee) do
      {:ok, _} ->
        updated_attachees = Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})
        {:noreply,
         socket
         |> assign(:attachees, updated_attachees)
         |> put_flash(:info, "Attachee deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete attachee")}
    end
  end

  # Handle updates for dependent dropdowns
  def handle_event("update", %{"attachee" => params}, socket) do
    org_id = safe_int(Map.get(params, "organization_id"))
    dept_id = safe_int(Map.get(params, "department_id"))

    # Load departments when organization changes
    departments = if org_id && org_id != safe_int(socket.assigns.form.params["organization_id"]) do
      Orgs.list_departments_by_org(org_id)
    else
      socket.assigns.departments
    end

    # Load programs when department changes
    programs = if dept_id && dept_id != safe_int(socket.assigns.form.params["department_id"]) do
      Eams.list_programs_by_department(dept_id)
    else
      socket.assigns.programs
    end

    # Clear department_id if organization changed
    params = if org_id && org_id != safe_int(socket.assigns.form.params["organization_id"]) do
      Map.put(params, "department_id", "")
    else
      params
    end

    # Clear program_id if department changed
    params = if dept_id && dept_id != safe_int(socket.assigns.form.params["department_id"]) do
      Map.put(params, "program_id", "")
    else
      params
    end

    # Get current form params and merge with new params
    current_params = socket.assigns.form.params
    merged_params = Map.merge(current_params, params)

    # Update changeset with merged params
    attachee = socket.assigns.editing_attachee || %Attachee{}
    changeset =
      attachee
      |> Attachee.changeset(merged_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, programs)}
  end

  # Save new or update attachee
  def handle_event("save", %{"attachee" => params}, socket) do
    # Convert string IDs to integers and parse dates
    attrs = %{
      user_id: safe_int(params["user_id"]),
      organization_id: safe_int(params["organization_id"]),
      department_id: safe_int(params["department_id"]),
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: params["status"] || "active"
    }

    program_id = safe_int(params["program_id"])

    result = if socket.assigns.editing_attachee do
      Eams.update_attachee(socket.assigns.editing_attachee, attrs)
    else
      Eams.create_attachee(attrs)
    end

    case result do
      {:ok, attachee} ->
        # Enroll in program (if selected)
        if program_id do
          Eams.enroll_attachee_in_program(attachee.id, program_id)
        end

        # Reload attachees list
        updated_attachees =
          Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})

        # Reset form
        changeset = Attachee.changeset(%Attachee{}, %{})

        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:editing_attachee, nil)
         |> assign(:form, to_form(changeset))
         |> assign(:attachees, updated_attachees)
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> put_flash(:info, "Attachee #{if socket.assigns.editing_attachee, do: "updated", else: "created"} successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Failed to save attachee. Please check the errors.")}
    end
  end

  # Helpers
  defp safe_int(value) when is_binary(value) and value != "", do: String.to_integer(value)
  defp safe_int(_), do: nil

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(_), do: nil

  defp translate_errors(errors) do
    Enum.map_join(errors, ", ", fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_initials(username) when is_binary(username) do
    username
    |> String.slice(0..1)
    |> String.upcase()
  end
  defp get_initials(_), do: "A"

  defp status_color("active"), do: "bg-emerald-50 text-emerald-700"
  defp status_color("inactive"), do: "bg-amber-50 text-amber-700"
  defp status_color("completed"), do: "bg-blue-50 text-blue-700"
  defp status_color(_), do: "bg-gray-50 text-gray-700"

  defp filtered_attachees(attachees, "all"), do: attachees
  defp filtered_attachees(attachees, status), do: Enum.filter(attachees, &(&1.status == status))
end
