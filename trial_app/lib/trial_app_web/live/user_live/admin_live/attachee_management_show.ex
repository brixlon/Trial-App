defmodule TrialAppWeb.AdminLive.AttacheeManagementShow do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialAppWeb.BreadcrumbComponent

  # Mount for STANDALONE attachee management view
  def mount(%{"id" => id}, _session, socket) do
    attachee = Eams.get_attachee_with_details(String.to_integer(id))

    tasks = Eams.list_tasks_by_attachee(attachee.id)
    evaluations = Eams.list_evaluations_by_attachee(attachee.id)
    stats = Eams.get_attachee_stats(attachee.id)
    eval_summary = Eams.get_evaluation_summary(attachee.id)

    # Breadcrumbs for STANDALONE management view
    breadcrumbs = [
      %{label: "Attachee Management", link: ~p"/admin/eams/attachees/manage"},
      %{label: attachee_name(attachee), link: nil}
    ]

    {:ok,
     socket
     |> assign(:attachee, attachee)
     |> assign(:tasks, tasks)
     |> assign(:evaluations, evaluations)
     |> assign(:stats, stats)
     |> assign(:eval_summary, eval_summary)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, attachee_name(attachee))
     |> assign(:show_eval_modal, false)
     |> assign(:viewing_evaluation, nil)
     |> assign(:eval_form, %{"score" => "", "comments" => ""})
     |> assign(:eval_errors, %{})
     |> assign(:active_tab, "overview")
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})}
  end

  # Tab switching
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Evaluation modal
  def handle_event("open_eval_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_eval_modal, true)
     |> assign(:eval_form, %{"score" => "", "comments" => ""})
     |> assign(:eval_errors, %{})}
  end

  def handle_event("close_eval_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_eval_modal, false)
     |> assign(:eval_form, %{"score" => "", "comments" => ""})
     |> assign(:eval_errors, %{})}
  end

  def handle_event("update_eval_form", %{"eval" => params}, socket) do
    {:noreply, assign(socket, :eval_form, params)}
  end

  def handle_event("submit_evaluation", %{"eval" => params}, socket) do
    attrs = %{
      score: parse_int(params["score"]),
      comments: params["comments"],
      attachee_id: socket.assigns.attachee.id,
      evaluator_id: socket.assigns.current_scope.id
    }

    case Eams.create_evaluation(attrs, socket.assigns.current_scope) do
      {:ok, _evaluation} ->
        evaluations = Eams.list_evaluations_by_attachee(socket.assigns.attachee.id)
        stats = Eams.get_attachee_stats(socket.assigns.attachee.id)
        eval_summary = Eams.get_evaluation_summary(socket.assigns.attachee.id)

        {:noreply,
         socket
         |> assign(:evaluations, evaluations)
         |> assign(:stats, stats)
         |> assign(:eval_summary, eval_summary)
         |> assign(:show_eval_modal, false)
         |> assign(:eval_form, %{"score" => "", "comments" => ""})
         |> assign(:eval_errors, %{})
         |> put_flash(:info, "Evaluation submitted successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> {field, msg} end)
          |> Enum.into(%{})

        {:noreply, assign(socket, :eval_errors, errors)}
    end
  end

  # View evaluation details
  def handle_event("view_evaluation", %{"id" => id}, socket) do
    evaluation = Eams.get_evaluation!(String.to_integer(id))
                  |> TrialApp.Repo.preload([:evaluator])
    {:noreply, assign(socket, :viewing_evaluation, evaluation)}
  end

  def handle_event("close_eval_view", _params, socket) do
    {:noreply, assign(socket, :viewing_evaluation, nil)}
  end

  # Helper functions
  defp attachee_name(attachee) do
    if Ecto.assoc_loaded?(attachee.user) && attachee.user do
      attachee.user.username || attachee.user.email
    else
      "Attachee ##{attachee.id}"
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_int(val) when is_integer(val), do: val

  defp task_status_color(status) do
    case status do
      "completed" -> "bg-green-100 text-green-800"
      "in_progress" -> "bg-blue-100 text-blue-800"
      "submitted" -> "bg-purple-100 text-purple-800"
      "rejected" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp score_color(score) when score >= 81, do: "text-green-600"
  defp score_color(score) when score >= 61, do: "text-blue-600"
  defp score_color(score) when score >= 41, do: "text-amber-600"
  defp score_color(_), do: "text-red-600"

  defp score_bg_color(score) when score >= 81, do: "bg-green-600 text-white"
  defp score_bg_color(score) when score >= 61, do: "bg-blue-600 text-white"
  defp score_bg_color(score) when score >= 41, do: "bg-amber-600 text-white"
  defp score_bg_color(_), do: "bg-red-600 text-white"

  defp score_label(score) when score >= 81, do: "Excellent"
  defp score_label(score) when score >= 61, do: "Good"
  defp score_label(score) when score >= 41, do: "Satisfactory"
  defp score_label(_), do: "Needs Improvement"

  defp trend_icon("improving") do
    ~s(<svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/></svg>)
  end
  defp trend_icon("declining") do
    ~s(<svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"/></svg>)
  end
  defp trend_icon(_) do
    ~s(<svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14"/></svg>)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <.live_component
        module={TrialAppWeb.SidebarComponent}
        id="sidebar"
        current_scope={@current_scope}
      />

      <div class="ml-64 p-8">
        <div class="max-w-7xl mx-auto space-y-6">
          <!-- Breadcrumb -->
          <BreadcrumbComponent.breadcrumb items={@breadcrumbs} />

          <!-- Compact Attachee Profile Card -->
          <div class="bg-white shadow rounded-xl overflow-hidden border border-gray-200">
            <div class="p-6">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <!-- Avatar -->
                  <div class="w-16 h-16 rounded-full bg-purple-600 flex items-center justify-center text-white text-2xl font-bold">
                    <%= if Ecto.assoc_loaded?(@attachee.user) && @attachee.user && @attachee.user.username do %>
                      <%= String.first(@attachee.user.username) |> String.upcase() %>
                    <% else %>
                      A
                    <% end %>
                  </div>

                  <div>
                    <h1 class="text-2xl font-bold text-gray-900"><%= attachee_name(@attachee) %></h1>
                    <p class="text-sm text-gray-500 mt-1"><%= @attachee.position %></p>
                    <div class="flex items-center gap-3 mt-2">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if @attachee.status == "active", do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800"}"}>
                        <%= String.capitalize(@attachee.status) %>
                      </span>
                      <%= if @eval_summary.total_evaluations > 0 do %>
                        <div class="flex items-center gap-2 text-sm text-gray-600">
                          <svg class="w-4 h-4 text-amber-500" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                          </svg>
                          <span class="font-semibold text-purple-600"><%= @eval_summary.average_score %></span>
                          <span class="text-gray-500">avg score</span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <button
                  phx-click="open_eval_modal"
                  class="bg-purple-600 text-white px-5 py-2.5 rounded-lg text-sm font-medium hover:bg-purple-700 transition shadow flex items-center gap-2"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                  </svg>
                  Evaluate
                </button>
              </div>

              <!-- Quick Stats -->
              <div class="grid grid-cols-4 gap-4 mt-6 pt-6 border-t border-gray-200">
                <div class="text-center">
                  <div class="text-2xl font-bold text-gray-900"><%= @stats.total_projects %></div>
                  <div class="text-xs text-gray-500 uppercase mt-1">Projects</div>
                </div>
                <div class="text-center">
                  <div class="text-2xl font-bold text-gray-900"><%= @stats.completed_tasks %>/<%= @stats.total_tasks %></div>
                  <div class="text-xs text-gray-500 uppercase mt-1">Tasks Done</div>
                </div>
                <div class="text-center">
                  <div class="text-2xl font-bold text-green-600"><%= @stats.completion_rate %>%</div>
                  <div class="text-xs text-gray-500 uppercase mt-1">Completion</div>
                </div>
                <div class="text-center">
                  <div class="text-2xl font-bold text-purple-600"><%= @eval_summary.total_evaluations %></div>
                  <div class="text-xs text-gray-500 uppercase mt-1">Evaluations</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tabs -->
          <div class="bg-white shadow rounded-xl overflow-hidden border border-gray-200">
            <div class="border-b border-gray-200">
              <div class="flex gap-1 p-2">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="overview"
                  class={[
                    "px-4 py-2 text-sm font-medium rounded-lg transition",
                    @active_tab == "overview" && "bg-purple-600 text-white",
                    @active_tab != "overview" && "text-gray-600 hover:bg-gray-100"
                  ]}
                >
                  Overview
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="tasks"
                  class={[
                    "px-4 py-2 text-sm font-medium rounded-lg transition",
                    @active_tab == "tasks" && "bg-purple-600 text-white",
                    @active_tab != "tasks" && "text-gray-600 hover:bg-gray-100"
                  ]}
                >
                  Tasks (<%= length(@tasks) %>)
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="evaluations"
                  class={[
                    "px-4 py-2 text-sm font-medium rounded-lg transition",
                    @active_tab == "evaluations" && "bg-purple-600 text-white",
                    @active_tab != "evaluations" && "text-gray-600 hover:bg-gray-100"
                  ]}
                >
                  Evaluations (<%= length(@evaluations) %>)
                </button>
              </div>
            </div>

            <!-- Tab Content -->
            <div class="p-6">
              <%= case @active_tab do %>
                <% "overview" -> %>
                  <div class="space-y-6">
                    <!-- Personal Information -->
                    <div>
                      <h3 class="text-lg font-semibold text-gray-900 mb-4">Personal Information</h3>
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <%= if Ecto.assoc_loaded?(@attachee.user) && @attachee.user do %>
                          <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                            <div class="text-xs text-gray-500 font-medium uppercase mb-1">Email</div>
                            <div class="text-sm font-semibold text-gray-900"><%= @attachee.user.email %></div>
                          </div>
                        <% end %>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <div class="text-xs text-gray-500 font-medium uppercase mb-1">Position</div>
                          <div class="text-sm font-semibold text-gray-900"><%= @attachee.position %></div>
                        </div>

                        <%= if @attachee.starts_on do %>
                          <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                            <div class="text-xs text-gray-500 font-medium uppercase mb-1">Start Date</div>
                            <div class="text-sm font-semibold text-gray-900">
                              <%= Calendar.strftime(@attachee.starts_on, "%B %d, %Y") %>
                            </div>
                          </div>
                        <% end %>

                        <%= if @attachee.ends_on do %>
                          <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                            <div class="text-xs text-gray-500 font-medium uppercase mb-1">End Date</div>
                            <div class="text-sm font-semibold text-gray-900">
                              <%= Calendar.strftime(@attachee.ends_on, "%B %d, %Y") %>
                            </div>
                          </div>
                        <% end %>

                        <%= if Ecto.assoc_loaded?(@attachee.department) && @attachee.department do %>
                          <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                            <div class="text-xs text-gray-500 font-medium uppercase mb-1">Department</div>
                            <div class="text-sm font-semibold text-gray-900"><%= @attachee.department.name %></div>
                          </div>
                        <% end %>

                        <%= if Ecto.assoc_loaded?(@attachee.organization) && @attachee.organization do %>
                          <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                            <div class="text-xs text-gray-500 font-medium uppercase mb-1">Organization</div>
                            <div class="text-sm font-semibold text-gray-900"><%= @attachee.organization.name %></div>
                          </div>
                        <% end %>
                      </div>
                    </div>

                    <!-- Performance Overview -->
                    <%= if @eval_summary.total_evaluations > 0 do %>
                      <div>
                        <h3 class="text-lg font-semibold text-gray-900 mb-4">Performance Overview</h3>
                        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                          <div class="bg-purple-50 p-4 rounded-lg border border-purple-200">
                            <div class="text-xs text-purple-600 font-medium uppercase">Average Score</div>
                            <div class={"text-3xl font-bold mt-2 #{score_color(@eval_summary.average_score)}"}><%= @eval_summary.average_score %></div>
                          </div>
                          <div class="bg-green-50 p-4 rounded-lg border border-green-200">
                            <div class="text-xs text-green-600 font-medium uppercase">Highest Score</div>
                            <div class="text-3xl font-bold text-green-600 mt-2"><%= @eval_summary.highest_score %></div>
                          </div>
                          <div class="bg-blue-50 p-4 rounded-lg border border-blue-200">
                            <div class="text-xs text-blue-600 font-medium uppercase">Latest Score</div>
                            <div class={"text-3xl font-bold mt-2 #{score_color(@eval_summary.latest_score)}"}><%= @eval_summary.latest_score %></div>
                          </div>
                          <div class="bg-amber-50 p-4 rounded-lg border border-amber-200">
                            <div class="text-xs text-amber-600 font-medium uppercase">Trend</div>
                            <div class="flex items-center gap-2 mt-2">
                              <%= Phoenix.HTML.raw(trend_icon(@eval_summary.trend)) %>
                              <span class="text-lg font-bold capitalize"><%= @eval_summary.trend %></span>
                            </div>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>

                <% "tasks" -> %>
                  <%= if @tasks == [] do %>
                    <div class="text-center py-12">
                      <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                      </svg>
                      <h3 class="text-lg font-medium text-gray-900 mb-2">No tasks yet</h3>
                      <p class="text-gray-500">Tasks will appear here when assigned</p>
                    </div>
                  <% else %>
                    <div class="space-y-3">
                      <%= for task <- @tasks do %>
                        <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition">
                          <div class="flex items-start justify-between mb-2">
                            <div class="flex-1">
                              <h4 class="font-semibold text-gray-900 mb-1"><%= task.title %></h4>
                              <%= if task.description do %>
                                <p class="text-sm text-gray-600 mb-2"><%= task.description %></p>
                              <% end %>
                            </div>
                            <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{task_status_color(task.status)}"}>
                              <%= String.capitalize(String.replace(task.status, "_", " ")) %>
                            </span>
                          </div>

                          <div class="flex items-center gap-4 text-sm text-gray-500">
                            <%= if Ecto.assoc_loaded?(task.project) && task.project do %>
                              <div class="flex items-center gap-1">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/>
                                </svg>
                                <span><%= task.project.name %></span>
                              </div>
                            <% end %>

                            <%= if task.due_on do %>
                              <div class="flex items-center gap-1">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                                </svg>
                                <span>Due: <%= Calendar.strftime(task.due_on, "%b %d, %Y") %></span>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                <% "evaluations" -> %>
                  <%= if @evaluations == [] do %>
                    <div class="text-center py-12">
                      <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <h3 class="text-lg font-medium text-gray-900 mb-2">No evaluations yet</h3>
                      <p class="text-gray-500 mb-4">Start by submitting the first evaluation</p>
                      <button
                        phx-click="open_eval_modal"
                        class="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition"
                      >
                        Submit Evaluation
                      </button>
                    </div>
                  <% else %>
                    <!-- Evaluation Summary Stats -->
                    <div class="flex items-center justify-end gap-6 mb-6">
                      <div class="text-center">
                        <div class="text-2xl font-bold text-purple-600"><%= @eval_summary.average_score %></div>
                        <div class="text-xs text-gray-500 uppercase">Average Score</div>
                      </div>
                      <div class="text-center">
                        <div class="text-2xl font-bold text-gray-900"><%= @eval_summary.total_evaluations %></div>
                        <div class="text-xs text-gray-500 uppercase">Total Evaluations</div>
                      </div>
                    </div>

                    <!-- Evaluation List -->
                    <div class="space-y-4 max-h-[600px] overflow-y-auto">
                      <%= for evaluation <- @evaluations do %>
                        <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition">
                          <div class="flex justify-between items-start mb-3">
                            <div class="flex items-center gap-3">
                              <div class={"w-12 h-12 rounded-full flex items-center justify-center text-xl font-bold #{score_bg_color(evaluation.score)}"}>
                                <%= evaluation.score %>
                              </div>
                              <div>
                                <p class="font-semibold text-gray-900">
                                  Score: <%= evaluation.score %>/100
                                </p>
                                <p class="text-sm text-gray-500">
                                  <%= Calendar.strftime(evaluation.inserted_at, "%B %d, %Y at %I:%M %p") %>
                                </p>
                                <%= if Ecto.assoc_loaded?(evaluation.evaluator) && evaluation.evaluator do %>
                                  <p class="text-sm text-gray-500">
                                    By: <%= evaluation.evaluator.username || evaluation.evaluator.email %>
                                  </p>
                                <% end %>
                              </div>
                            </div>

                            <button
                              phx-click="view_evaluation"
                              phx-value-id={evaluation.id}
                              class="text-purple-600 hover:text-purple-700 text-sm font-medium"
                            >
                              View Details →
                            </button>
                          </div>

                          <%= if evaluation.comments do %>
                            <div class="bg-gray-50 p-3 rounded-lg border border-gray-200">
                              <p class="text-xs font-semibold text-gray-600 uppercase mb-1">Comments:</p>
                              <p class="text-sm text-gray-800"><%= evaluation.comments %></p>
                            </div>
                          <% end %>

                          <div class="flex justify-end mt-3">
                            <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{score_bg_color(evaluation.score)}"}>
                              <%= score_label(evaluation.score) %>
                            </span>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Evaluation Modal (same as before) -->
      <%= if @show_eval_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
              <div>
                <h2 class="text-xl font-bold text-gray-900">Evaluate <%= attachee_name(@attachee) %></h2>
                <p class="text-sm text-gray-500 mt-1">Provide a score and detailed feedback</p>
              </div>
              <button phx-click="close_eval_modal" class="text-gray-400 hover:text-gray-600 transition">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <form phx-submit="submit_evaluation" phx-change="update_eval_form">
              <div class="px-6 py-4 space-y-6">
                <%= if @eval_errors != %{} do %>
                  <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                    <div class="flex items-start gap-3">
                      <svg class="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <div>
                        <h3 class="text-sm font-semibold text-red-800">There were errors with your submission</h3>
                        <ul class="list-disc list-inside text-sm text-red-700 mt-2">
                          <%= for {field, message} <- @eval_errors do %>
                            <li><%= Phoenix.Naming.humanize(field) %>: <%= message %></li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
                <% end %>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Score <span class="text-red-600">*</span>
                  </label>
                  <input
                    type="number"
                    name="eval[score]"
                    value={@eval_form["score"]}
                    min="0"
                    max="100"
                    required
                    placeholder="Enter score (0-100)"
                    class={"w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent #{if @eval_errors[:score], do: "border-red-500", else: "border-gray-300"}"}
                  />
                  <%= if error = @eval_errors[:score] do %>
                    <p class="text-sm text-red-600 mt-1"><%= error %></p>
                  <% else %>
                    <p class="text-sm text-gray-500 mt-1">Rate the attachee's performance from 0 to 100</p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Comments</label>
                  <textarea
                    name="eval[comments]"
                    rows="6"
                    placeholder="Provide detailed feedback about the attachee's performance, strengths, and areas for improvement..."
                    class={"w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent #{if @eval_errors[:comments], do: "border-red-500", else: "border-gray-300"}"}
                  ><%= @eval_form["comments"] %></textarea>
                  <%= if error = @eval_errors[:comments] do %>
                    <p class="text-sm text-red-600 mt-1"><%= error %></p>
                  <% else %>
                    <p class="text-sm text-gray-500 mt-1">Optional: Add specific feedback and observations</p>
                  <% end %>
                </div>

                <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                  <h4 class="text-sm font-semibold text-gray-900 mb-3">Scoring Guide</h4>
                  <div class="space-y-2 text-sm">
                    <div class="flex items-center gap-3">
                      <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 w-20">81-100</span>
                      <span class="text-gray-700">Excellent - Exceeds expectations</span>
                    </div>
                    <div class="flex items-center gap-3">
                      <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 w-20">61-80</span>
                      <span class="text-gray-700">Good - Meets expectations</span>
                    </div>
                    <div class="flex items-center gap-3">
                      <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800 w-20">41-60</span>
                      <span class="text-gray-700">Satisfactory - Needs improvement</span>
                    </div>
                    <div class="flex items-center gap-3">
                      <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800 w-20">0-40</span>
                      <span class="text-gray-700">Needs Improvement - Requires attention</span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="px-6 py-4 border-t border-gray-200 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_eval_modal"
                  class="px-4 py-2 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-100 transition border border-gray-300"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition shadow"
                >
                  Submit Evaluation
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <!-- Evaluation Details Modal -->
      <%= if @viewing_evaluation do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-xl max-w-3xl w-full max-h-[90vh] overflow-y-auto">
            <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
              <div>
                <h2 class="text-xl font-bold text-gray-900">Evaluation Details</h2>
                <p class="text-sm text-gray-500 mt-1">
                  Submitted <%= Calendar.strftime(@viewing_evaluation.inserted_at, "%B %d, %Y at %I:%M %p") %>
                </p>
              </div>
              <button phx-click="close_eval_view" class="text-gray-400 hover:text-gray-600 transition">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="px-6 py-6 space-y-6">
              <div class="flex items-center justify-center">
                <div class="text-center">
                  <div class={"w-32 h-32 rounded-full flex items-center justify-center text-5xl font-bold mx-auto #{score_bg_color(@viewing_evaluation.score)}"}>
                    <%= @viewing_evaluation.score %>
                  </div>
                  <div class="text-2xl font-bold text-gray-900 mt-4">
                    <%= @viewing_evaluation.score %> out of 100
                  </div>
                  <div class={"text-sm font-medium mt-2 #{score_color(@viewing_evaluation.score)}"}>
                    <%= score_label(@viewing_evaluation.score) %>
                  </div>
                </div>
              </div>

              <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
                <h3 class="text-sm font-semibold text-gray-600 uppercase mb-4">Evaluator Information</h3>
                <div class="flex items-center gap-4">
                  <div class="w-12 h-12 rounded-full bg-purple-600 flex items-center justify-center text-white text-xl font-bold">
                    <%= if @viewing_evaluation.evaluator && @viewing_evaluation.evaluator.username do %>
                      <%= String.first(@viewing_evaluation.evaluator.username) |> String.upcase() %>
                    <% else %>
                      E
                    <% end %>
                  </div>
                  <div>
                    <div class="font-semibold text-gray-900">
                      <%= if @viewing_evaluation.evaluator do %>
                        <%= @viewing_evaluation.evaluator.username || @viewing_evaluation.evaluator.email %>
                      <% else %>
                        Unknown Evaluator
                      <% end %>
                    </div>
                    <%= if @viewing_evaluation.evaluator && @viewing_evaluation.evaluator.email do %>
                      <div class="text-sm text-gray-600"><%= @viewing_evaluation.evaluator.email %></div>
                    <% end %>
                  </div>
                </div>
              </div>

              <%= if @viewing_evaluation.comments do %>
                <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
                  <h3 class="text-sm font-semibold text-gray-600 uppercase mb-3">Feedback & Comments</h3>
                  <div class="text-gray-800 whitespace-pre-wrap">
                    <%= @viewing_evaluation.comments %>
                  </div>
                </div>
              <% else %>
                <div class="bg-gray-50 rounded-lg p-6 text-center border border-gray-200">
                  <svg class="w-12 h-12 mx-auto text-gray-300 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
                  </svg>
                  <p class="text-sm text-gray-500">No comments provided for this evaluation</p>
                </div>
              <% end %>

              <div class="grid grid-cols-2 gap-4">
                <div class="bg-blue-50 p-4 rounded-lg border border-blue-200">
                  <div class="text-xs text-blue-600 font-medium uppercase">Submitted On</div>
                  <div class="text-lg font-bold text-blue-900 mt-1">
                    <%= Calendar.strftime(@viewing_evaluation.inserted_at, "%B %d, %Y") %>
                  </div>
                  <div class="text-sm text-blue-700 mt-1">
                    <%= Calendar.strftime(@viewing_evaluation.inserted_at, "%I:%M %p") %>
                  </div>
                </div>

                <div class="bg-purple-50 p-4 rounded-lg border border-purple-200">
                  <div class="text-xs text-purple-600 font-medium uppercase">Evaluation ID</div>
                  <div class="text-lg font-bold text-purple-900 mt-1 font-mono">
                    #<%= @viewing_evaluation.id %>
                  </div>
                </div>
              </div>
            </div>

            <div class="px-6 py-4 border-t border-gray-200 flex justify-end">
              <button
                type="button"
                phx-click="close_eval_view"
                class="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition shadow"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
