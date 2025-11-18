defmodule TrialAppWeb.AdminLive.AttacheeShow do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialAppWeb.BreadcrumbComponent

  def mount(%{"program_id" => program_id, "project_id" => project_id, "id" => id}, _session, socket) do
    attachee = Eams.get_attachee_with_details(String.to_integer(id))
    program = Eams.get_program!(String.to_integer(program_id))
    project = Eams.get_project!(String.to_integer(project_id))

    tasks = Eams.list_tasks_by_attachee(attachee.id)
    evaluations = Eams.list_evaluations_by_attachee(attachee.id)
    stats = Eams.get_attachee_stats(attachee.id)
    eval_summary = Eams.get_evaluation_summary(attachee.id)

    breadcrumbs = [
      %{label: "Programs", link: ~p"/admin/eams/programs"},
      %{label: program.name, link: ~p"/admin/eams/programs/#{program.id}"},
      %{label: project.name, link: ~p"/admin/eams/programs/#{program.id}/projects/#{project.id}"},
      %{label: attachee_name(attachee), link: nil}
    ]

    {:ok,
     socket
     |> assign(:attachee, attachee)
     |> assign(:program, program)
     |> assign(:project, project)
     |> assign(:tasks, tasks)
     |> assign(:evaluations, evaluations)
     |> assign(:stats, stats)
     |> assign(:eval_summary, eval_summary)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, attachee_name(attachee))
     |> assign(:show_eval_modal, false)
     |> assign(:show_task_modal, false)
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

  defp score_color(score) when score >= 80, do: "text-green-600"
  defp score_color(score) when score >= 60, do: "text-blue-600"
  defp score_color(score) when score >= 40, do: "text-amber-600"
  defp score_color(_), do: "text-red-600"

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
    <div class="min-h-screen bg-gray-50">
      <div class="flex">
        <!-- Sidebar -->
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <!-- Main Content -->
        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-6">
            <!-- Breadcrumb -->
            <BreadcrumbComponent.breadcrumb items={@breadcrumbs} />

            <!-- Attachee Header Card -->
            <div class="bg-gradient-to-r from-purple-600 to-pink-600 rounded-2xl shadow-xl p-8 text-white">
              <div class="flex items-start gap-6">
                <!-- Avatar -->
                <div class="w-24 h-24 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center text-4xl font-bold flex-shrink-0 border-4 border-white/30">
                  <%= if Ecto.assoc_loaded?(@attachee.user) && @attachee.user && @attachee.user.username do %>
                    <%= String.first(@attachee.user.username) |> String.upcase() %>
                  <% else %>
                    A
                  <% end %>
                </div>

                <div class="flex-1">
                  <h1 class="text-4xl font-bold mb-2"><%= attachee_name(@attachee) %></h1>
                  <p class="text-xl text-purple-100 mb-4"><%= @attachee.position %></p>

                  <div class="flex items-center gap-4">
                    <span class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{if @attachee.status == "active", do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800"}"}>
                      <%= String.capitalize(@attachee.status) %>
                    </span>

                    <%= if @eval_summary.total_evaluations > 0 do %>
                      <div class="flex items-center gap-2 bg-white/10 backdrop-blur-sm px-4 py-2 rounded-lg">
                        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                        </svg>
                        <span class="font-bold text-lg"><%= @eval_summary.average_score %></span>
                        <span class="text-sm opacity-90">Average Score</span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <button
                  phx-click="open_eval_modal"
                  class="flex items-center gap-2 px-6 py-3 bg-white text-purple-600 rounded-lg hover:bg-purple-50 transition shadow-lg font-medium"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                  </svg>
                  Evaluate
                </button>
              </div>

              <!-- Quick Stats -->
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
                <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4">
                  <div class="text-sm text-purple-100">Projects</div>
                  <div class="text-2xl font-bold"><%= @stats.total_projects %></div>
                </div>
                <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4">
                  <div class="text-sm text-purple-100">Tasks Completed</div>
                  <div class="text-2xl font-bold"><%= @stats.completed_tasks %>/<%= @stats.total_tasks %></div>
                </div>
                <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4">
                  <div class="text-sm text-purple-100">Completion Rate</div>
                  <div class="text-2xl font-bold"><%= @stats.completion_rate %>%</div>
                </div>
                <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4">
                  <div class="text-sm text-purple-100">Evaluations</div>
                  <div class="text-2xl font-bold"><%= @eval_summary.total_evaluations %></div>
                </div>
              </div>
            </div>

            <!-- Tabs -->
            <div class="bg-white rounded-xl shadow-sm">
              <div class="border-b border-gray-200">
                <nav class="flex -mb-px">
                  <button
                    phx-click="switch_tab"
                    phx-value-tab="overview"
                    class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "overview", do: "border-purple-500 text-purple-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
                  >
                    Overview
                  </button>
                  <button
                    phx-click="switch_tab"
                    phx-value-tab="tasks"
                    class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "tasks", do: "border-purple-500 text-purple-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
                  >
                    Tasks (<%= length(@tasks) %>)
                  </button>
                  <button
                    phx-click="switch_tab"
                    phx-value-tab="evaluations"
                    class={"px-6 py-4 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "evaluations", do: "border-purple-500 text-purple-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
                  >
                    Evaluations (<%= length(@evaluations) %>)
                  </button>
                </nav>
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
                            <div class="bg-gray-50 rounded-lg p-4">
                              <div class="text-sm text-gray-600 mb-1">Email</div>
                              <div class="font-medium text-gray-900"><%= @attachee.user.email %></div>
                            </div>
                          <% end %>

                          <div class="bg-gray-50 rounded-lg p-4">
                            <div class="text-sm text-gray-600 mb-1">Position</div>
                            <div class="font-medium text-gray-900"><%= @attachee.position %></div>
                          </div>

                          <%= if @attachee.starts_on do %>
                            <div class="bg-gray-50 rounded-lg p-4">
                              <div class="text-sm text-gray-600 mb-1">Start Date</div>
                              <div class="font-medium text-gray-900">
                                <%= Calendar.strftime(@attachee.starts_on, "%B %d, %Y") %>
                              </div>
                            </div>
                          <% end %>

                          <%= if @attachee.ends_on do %>
                            <div class="bg-gray-50 rounded-lg p-4">
                              <div class="text-sm text-gray-600 mb-1">End Date</div>
                              <div class="font-medium text-gray-900">
                                <%= Calendar.strftime(@attachee.ends_on, "%B %d, %Y") %>
                              </div>
                            </div>
                          <% end %>

                          <%= if Ecto.assoc_loaded?(@attachee.department) && @attachee.department do %>
                            <div class="bg-gray-50 rounded-lg p-4">
                              <div class="text-sm text-gray-600 mb-1">Department</div>
                              <div class="font-medium text-gray-900"><%= @attachee.department.name %></div>
                            </div>
                          <% end %>

                          <%= if Ecto.assoc_loaded?(@attachee.organization) && @attachee.organization do %>
                            <div class="bg-gray-50 rounded-lg p-4">
                              <div class="text-sm text-gray-600 mb-1">Organization</div>
                              <div class="font-medium text-gray-900"><%= @attachee.organization.name %></div>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <!-- Performance Overview -->
                      <%= if @eval_summary.total_evaluations > 0 do %>
                        <div>
                          <h3 class="text-lg font-semibold text-gray-900 mb-4">Performance Overview</h3>
                          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                            <div class="bg-purple-50 rounded-lg p-4 border border-purple-100">
                              <div class="text-sm text-purple-600 font-medium mb-1">Average Score</div>
                              <div class={"text-3xl font-bold #{score_color(@eval_summary.average_score)}"}><%= @eval_summary.average_score %></div>
                            </div>
                            <div class="bg-green-50 rounded-lg p-4 border border-green-100">
                              <div class="text-sm text-green-600 font-medium mb-1">Highest Score</div>
                              <div class="text-3xl font-bold text-green-600"><%= @eval_summary.highest_score %></div>
                            </div>
                            <div class="bg-blue-50 rounded-lg p-4 border border-blue-100">
                              <div class="text-sm text-blue-600 font-medium mb-1">Latest Score</div>
                              <div class={"text-3xl font-bold #{score_color(@eval_summary.latest_score)}"}><%= @eval_summary.latest_score %></div>
                            </div>
                            <div class="bg-amber-50 rounded-lg p-4 border border-amber-100">
                              <div class="text-sm text-amber-600 font-medium mb-1">Trend</div>
                              <div class="flex items-center gap-2">
                                <%= Phoenix.HTML.raw(trend_icon(@eval_summary.trend)) %>
                                <span class="text-lg font-bold text-gray-900 capitalize"><%= @eval_summary.trend %></span>
                              </div>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>

                  <% "tasks" -> %>
                    <%= if @tasks == [] do %>
                      <div class="text-center py-12">
                        <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                        </svg>
                        <h3 class="text-lg font-medium text-gray-900 mb-2">No tasks yet</h3>
                        <p class="text-gray-600">Tasks will appear here when assigned</p>
                      </div>
                    <% else %>
                      <div class="space-y-4">
                        <%= for task <- @tasks do %>
                          <div class="border border-gray-200 rounded-lg p-4 hover:border-purple-300 transition">
                            <div class="flex items-start justify-between mb-2">
                              <div class="flex-1">
                                <h4 class="font-semibold text-gray-900 mb-1"><%= task.title %></h4>
                                <%= if task.description do %>
                                  <p class="text-sm text-gray-600 mb-2"><%= task.description %></p>
                                <% end %>
                              </div>
                              <span class={"inline-flex items-center px-3 py-1 rounded-full text-xs font-medium #{task_status_color(task.status)}"}>
                                <%= String.capitalize(String.replace(task.status, "_", " ")) %>
                              </span>
                            </div>

                            <div class="flex items-center gap-4 text-sm text-gray-600">
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
                        <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                        </svg>
                        <h3 class="text-lg font-medium text-gray-900 mb-2">No evaluations yet</h3>
                        <p class="text-gray-600 mb-4">Start by submitting the first evaluation</p>
                        <button
                          phx-click="open_eval_modal"
                          class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition"
                        >
                          Submit Evaluation
                        </button>
                      </div>
                    <% else %>
                      <div class="space-y-4">
                        <%= for evaluation <- @evaluations do %>
                          <div class="border border-gray-200 rounded-lg p-6 hover:border-purple-300 transition">
                            <div class="flex items-start justify-between mb-4">
                              <div class="flex items-center gap-4">
                                <div class={"w-16 h-16 rounded-full flex items-center justify-center text-2xl font-bold #{if evaluation.score >= 70, do: "bg-green-100 text-green-600", else: "bg-amber-100 text-amber-600"}"}>
                                  <%= evaluation.score %>
                                </div>
                                <div>
                                  <div class="font-semibold text-gray-900">
                                    Score: <%= evaluation.score %>/100
                                  </div>
                                  <div class="text-sm text-gray-600">
                                    <%= Calendar.strftime(evaluation.inserted_at, "%B %d, %Y at %I:%M %p") %>
                                  </div>
                                  <%= if Ecto.assoc_loaded?(evaluation.evaluator) && evaluation.evaluator do %>
                                    <div class="text-sm text-gray-600">
                                      By: <%= evaluation.evaluator.username || evaluation.evaluator.email %>
                                    </div>
                                  <% end %>
                                </div>
                              </div>

                              <button
                                phx-click="view_evaluation"
                                phx-value-id={evaluation.id}
                                class="text-purple-600 hover:text-purple-700 font-medium text-sm"
                              >
                                View Details →
                              </button>
                            </div>

                            <%= if evaluation.comments do %>
                              <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                                <div class="text-sm font-medium text-gray-700 mb-2">Comments:</div>
                                <p class="text-sm text-gray-600"><%= evaluation.comments %></p>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>

    <%!-- Evaluation Modal --%>
    <%= if @show_eval_modal do %>
      <div class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
        <div class="bg-white rounded-2xl w-full max-w-2xl shadow-2xl">
          <!-- Modal Header -->
          <div class="flex items-center justify-between px-8 py-6 border-b border-gray-200">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Evaluate <%= attachee_name(@attachee) %></h2>
              <p class="text-sm text-gray-500 mt-1">Provide a score and detailed feedback</p>
            </div>
            <button phx-click="close_eval_modal" class="p-2 hover:bg-gray-100 rounded-lg transition-colors">
              <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Modal Body -->
          <form id="eval-form" phx-submit="submit_evaluation" phx-change="update_eval_form">
            <div class="px-8 py-6 space-y-6">
              <!-- Error Banner -->
              <%= if @eval_errors != %{} do %>
                <div class="bg-red-50 border-l-4 border-red-500 rounded-lg p-4">
                  <div class="flex items-start gap-3">
                    <svg class="w-5 h-5 text-red-500 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                    </svg>
                    <div>
                      <h3 class="text-sm font-medium text-red-800">There were errors with your submission</h3>
                      <div class="mt-2 text-sm text-red-700">
                        <ul class="list-disc list-inside space-y-1">
                          <%= for {field, message} <- @eval_errors do %>
                            <li><%= Phoenix.Naming.humanize(field) %>: <%= message %></li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Score Input -->
              <div class="space-y-2">
                <label for="score" class="block text-sm font-medium text-gray-700">
                  Score <span class="text-red-500">*</span>
                </label>
                <div class="relative">
                  <input
                    type="number"
                    id="score"
                    name="eval[score]"
                    value={@eval_form["score"]}
                    min="0"
                    max="100"
                    required
                    class={"w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent transition #{if @eval_errors[:score], do: "border-red-500", else: "border-gray-300"}"}
                    placeholder="Enter score (0-100)"
                  />
                  <div class="absolute inset-y-0 right-0 flex items-center pr-4 pointer-events-none">
                    <span class="text-gray-500 text-sm">/100</span>
                  </div>
                </div>
                <%= if error = @eval_errors[:score] do %>
                  <p class="text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                    </svg>
                    <%= error %>
                  </p>
                <% else %>
                  <p class="text-sm text-gray-500">Rate the attachee's performance from 0 to 100</p>
                <% end %>
              </div>

              <!-- Comments Textarea -->
              <div class="space-y-2">
                <label for="comments" class="block text-sm font-medium text-gray-700">
                  Comments
                </label>
                <textarea
                  id="comments"
                  name="eval[comments]"
                  rows="6"
                  class={"w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent transition resize-none #{if @eval_errors[:comments], do: "border-red-500", else: "border-gray-300"}"}
                  placeholder="Provide detailed feedback about the attachee's performance, strengths, and areas for improvement..."
                ><%= @eval_form["comments"] %></textarea>
                <%= if error = @eval_errors[:comments] do %>
                  <p class="text-sm text-red-600 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                    </svg>
                    <%= error %>
                  </p>
                <% else %>
                  <p class="text-sm text-gray-500">Optional: Add specific feedback and observations</p>
                <% end %>
              </div>

              <!-- Score Guide -->
              <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                <h4 class="text-sm font-medium text-gray-700 mb-3">Scoring Guide</h4>
                <div class="space-y-2 text-sm">
                  <div class="flex items-center gap-3">
                    <span class="w-16 px-2 py-1 bg-green-100 text-green-800 rounded font-medium text-center">80-100</span>
                    <span class="text-gray-600">Outstanding performance, exceeds expectations</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-16 px-2 py-1 bg-blue-100 text-blue-800 rounded font-medium text-center">60-79</span>
                    <span class="text-gray-600">Good performance, meets expectations</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-16 px-2 py-1 bg-amber-100 text-amber-800 rounded font-medium text-center">40-59</span>
                    <span class="text-gray-600">Fair performance, needs improvement</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="w-16 px-2 py-1 bg-red-100 text-red-800 rounded font-medium text-center">0-39</span>
                    <span class="text-gray-600">Poor performance, requires attention</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Modal Footer -->
            <div class="flex items-center justify-end gap-3 px-8 py-6 bg-gray-50 border-t border-gray-200 rounded-b-2xl">
              <button
                type="button"
                phx-click="close_eval_modal"
                class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100 transition font-medium"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition font-medium shadow-lg hover:shadow-xl"
              >
                Submit Evaluation
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <%!-- Evaluation Details Modal --%>
    <%= if @viewing_evaluation do %>
      <div class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
        <div class="bg-white rounded-2xl w-full max-w-3xl shadow-2xl max-h-[90vh] overflow-hidden flex flex-col">
          <!-- Modal Header -->
          <div class="flex items-center justify-between px-8 py-6 border-b border-gray-200">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Evaluation Details</h2>
              <p class="text-sm text-gray-500 mt-1">
                Submitted <%= Calendar.strftime(@viewing_evaluation.inserted_at, "%B %d, %Y at %I:%M %p") %>
              </p>
            </div>
            <button phx-click="close_eval_view" class="p-2 hover:bg-gray-100 rounded-lg transition-colors">
              <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Modal Body -->
          <div class="flex-1 overflow-y-auto px-8 py-6 space-y-6">
            <!-- Score Display -->
            <div class="flex items-center justify-center">
              <div class="text-center">
                <div class={"w-32 h-32 rounded-full flex items-center justify-center text-5xl font-bold mx-auto mb-4 #{if @viewing_evaluation.score >= 70, do: "bg-green-100 text-green-600", else: "bg-amber-100 text-amber-600"}"}>
                  <%= @viewing_evaluation.score %>
                </div>
                <div class="text-2xl font-bold text-gray-900">
                  <%= @viewing_evaluation.score %> out of 100
                </div>
                <div class={"text-sm font-medium mt-2 #{score_color(@viewing_evaluation.score)}"}>
                  <%= cond do %>
                    <% @viewing_evaluation.score >= 80 -> %> Outstanding Performance
                    <% @viewing_evaluation.score >= 60 -> %> Good Performance
                    <% @viewing_evaluation.score >= 40 -> %> Fair Performance
                    <% true -> %> Needs Improvement
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Evaluator Info -->
            <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
              <h3 class="text-sm font-medium text-gray-700 mb-4">Evaluator Information</h3>
              <div class="flex items-center gap-4">
                <div class="w-12 h-12 rounded-full bg-purple-100 text-purple-600 flex items-center justify-center text-xl font-bold">
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

            <!-- Comments -->
            <%= if @viewing_evaluation.comments do %>
              <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
                <h3 class="text-sm font-medium text-gray-700 mb-3">Feedback & Comments</h3>
                <div class="prose prose-sm max-w-none text-gray-600">
                  <%= @viewing_evaluation.comments %>
                </div>
              </div>
            <% else %>
              <div class="bg-gray-50 rounded-lg p-6 border border-gray-200 text-center">
                <svg class="w-12 h-12 mx-auto text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
                </svg>
                <p class="text-sm text-gray-500">No comments provided for this evaluation</p>
              </div>
            <% end %>

            <!-- Metadata -->
            <div class="grid grid-cols-2 gap-4">
              <div class="bg-blue-50 rounded-lg p-4 border border-blue-100">
                <div class="text-sm text-blue-600 font-medium mb-1">Submitted On</div>
                <div class="font-semibold text-gray-900">
                  <%= Calendar.strftime(@viewing_evaluation.inserted_at, "%B %d, %Y") %>
                </div>
                <div class="text-sm text-gray-600">
                  <%= Calendar.strftime(@viewing_evaluation.inserted_at, "%I:%M %p") %>
                </div>
              </div>

              <div class="bg-purple-50 rounded-lg p-4 border border-purple-100">
                <div class="text-sm text-purple-600 font-medium mb-1">Evaluation ID</div>
                <div class="font-mono font-semibold text-gray-900 text-sm">
                  #<%= @viewing_evaluation.id %>
                </div>
              </div>
            </div>
          </div>

          <!-- Modal Footer -->
          <div class="flex items-center justify-end gap-3 px-8 py-6 bg-gray-50 border-t border-gray-200">
            <button
              type="button"
              phx-click="close_eval_view"
              class="px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition font-medium"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
