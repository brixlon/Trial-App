defmodule TrialAppWeb.SupervisorLive.EvaluationForm do
  use TrialAppWeb, :live_component

  alias TrialApp.Eams

  # 7 evaluation criteria with weights
  @evaluation_criteria [
    %{key: "teamwork", label: "Teamwork & Collaboration", weight: 15},
    %{key: "communication", label: "Communication Skills", weight: 10},
    %{key: "professionalism", label: "Professionalism", weight: 10},
    %{key: "initiative", label: "Initiative & Proactivity", weight: 15},
    %{key: "quality", label: "Quality of Work", weight: 20},
    %{key: "time_management", label: "Time Management", weight: 15},
    %{key: "learning", label: "Learning & Adaptability", weight: 15}
  ]

  def mount(socket) do
    {:ok, assign(socket, submitting: false)}
  end

  def update(assigns, socket) do
    tasks = Eams.list_tasks_for_attachee(assigns.attachee.id)

    # Initialize task scores - use actual rating if task has been rated, otherwise default to 50
    task_scores =
      Map.new(tasks, fn task ->
        score = if task.rating, do: rating_to_score(task.rating), else: 50
        {task.id, score}
      end)

    # Initialize criteria scores
    criteria_scores = Map.new(@evaluation_criteria, fn criteria -> {criteria.key, 50} end)

    changeset =
      %Eams.Evaluation{}
      |> Eams.Evaluation.changeset(
        %{
          attachee_id: assigns.attachee.id,
          evaluator_id: assigns.current_user.id,
          score: 50,
          comments: ""
        },
        assigns.current_user
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:tasks, tasks)
     |> assign(:task_scores, task_scores)
     |> assign(:criteria_scores, criteria_scores)
     |> assign(:calculated_score, 50.0)
     |> assign(:evaluation_criteria, @evaluation_criteria)}
  end

  # Handle task score updates
  def handle_event("update_task_score", %{"task_score" => task_scores_params}, socket) do
    {task_id_str, score_str} = Enum.at(task_scores_params, 0)
    task_id = String.to_integer(task_id_str)
    score = String.to_integer(score_str)

    task_scores = Map.put(socket.assigns.task_scores, task_id, score)

    calculated_score =
      calculate_total_score(task_scores, socket.assigns.criteria_scores, socket.assigns.tasks)

    {:noreply,
     socket
     |> assign(:task_scores, task_scores)
     |> assign(:calculated_score, calculated_score)}
  end

  # Handle criteria score updates
  def handle_event("update_criteria_score", %{"criteria_score" => criteria_params}, socket) do
    {criteria_key, score_str} = Enum.at(criteria_params, 0)
    score = String.to_integer(score_str)

    criteria_scores = Map.put(socket.assigns.criteria_scores, criteria_key, score)

    calculated_score =
      calculate_total_score(socket.assigns.task_scores, criteria_scores, socket.assigns.tasks)

    {:noreply,
     socket
     |> assign(:criteria_scores, criteria_scores)
     |> assign(:calculated_score, calculated_score)}
  end

  def handle_event("validate", %{"evaluation" => params}, socket) do
    params =
      Map.merge(params, %{
        "attachee_id" => socket.assigns.attachee.id,
        "evaluator_id" => socket.assigns.current_user.id,
        "score" => trunc(socket.assigns.calculated_score)
      })

    changeset =
      %Eams.Evaluation{}
      |> Eams.Evaluation.changeset(params, socket.assigns.current_user)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"evaluation" => params}, socket) do
    # Prevent double submission
    if socket.assigns.submitting do
      {:noreply, socket}
    else
      socket = assign(socket, :submitting, true)

      # Prepare detailed evaluation data for the main evaluation
      evaluation_details = %{
        "task_scores" => socket.assigns.task_scores,
        "criteria_scores" => socket.assigns.criteria_scores,
        "calculated_score" => socket.assigns.calculated_score
      }

      # Round score to integer since database expects integer type
      rounded_score = socket.assigns.calculated_score |> Float.round() |> trunc()

      # Calculate monthly scores
      start_date = socket.assigns.attachee.starts_on

      monthly_data =
        calculate_monthly_data(socket.assigns.tasks, socket.assigns.task_scores, start_date)

      # Create main/overall evaluation (without task_id)
      main_params = %{
        "attachee_id" => socket.assigns.attachee.id,
        "evaluator_id" => socket.assigns.current_user.id,
        "score" => rounded_score,
        "comments" => params["comments"],
        "evaluation_details" => Jason.encode!(evaluation_details),
        # New fields
        "evaluation_period_start" => start_date,
        "evaluation_period_end" => socket.assigns.attachee.ends_on,
        "is_final" => true,
        "month_1_score" => monthly_data.month_1.score,
        "month_2_score" => monthly_data.month_2.score,
        "month_3_score" => monthly_data.month_3.score,
        "month_1_tasks_count" => monthly_data.month_1.count,
        "month_2_tasks_count" => monthly_data.month_2.count,
        "month_3_tasks_count" => monthly_data.month_3.count
      }

      case Eams.create_evaluation(main_params, socket.assigns.current_user) do
        {:ok, _eval} ->
          # Create individual task evaluations so they show in Tasks & Scores tab
          Enum.each(socket.assigns.task_scores, fn {task_id, task_score} ->
            task = Enum.find(socket.assigns.tasks, fn t -> t.id == task_id end)
            task_title = if task, do: task.title, else: "Task ##{task_id}"

            task_params = %{
              "attachee_id" => socket.assigns.attachee.id,
              "evaluator_id" => socket.assigns.current_user.id,
              "score" => task_score,
              "task_id" => task_id,
              "comments" => "Task: #{task_title} - Score: #{task_score}/100"
            }

            Eams.create_evaluation(task_params, socket.assigns.current_user)
          end)

          send(self(), {:evaluation_submitted, socket.assigns.attachee.id})
          send(self(), :close_modal)
          {:noreply, socket}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, changeset: changeset, submitting: false)}
      end
    end
  end

  def handle_event("close", _, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end

  # Calculate total score: 50% from tasks, 50% from criteria
  defp calculate_total_score(task_scores, criteria_scores, _tasks) do
    # Calculate task score average (50% weight)
    task_avg =
      if map_size(task_scores) > 0 do
        task_sum = task_scores |> Map.values() |> Enum.sum()
        task_sum / map_size(task_scores)
      else
        50.0
      end

    # Calculate weighted criteria score (50% weight)
    criteria_weighted =
      @evaluation_criteria
      |> Enum.map(fn criteria ->
        score = Map.get(criteria_scores, criteria.key, 50)
        score * criteria.weight / 100
      end)
      |> Enum.sum()

    # Combine: 50% tasks + 50% criteria
    total = task_avg * 0.5 + criteria_weighted * 0.5

    Float.round(total, 1)
  end

  defp calculate_monthly_data(tasks, task_scores, start_date) do
    # Initialize monthly data
    initial_data = %{
      month_1: %{score: 0, count: 0, total: 0},
      month_2: %{score: 0, count: 0, total: 0},
      month_3: %{score: 0, count: 0, total: 0}
    }

    tasks
    |> Enum.reduce(initial_data, fn task, acc ->
      task_date = extract_date(task.inserted_at)
      score = Map.get(task_scores, task.id, 50)

      month_key =
        if start_date && task_date do
          diff_days = Date.diff(task_date, start_date)

          cond do
            diff_days <= 30 -> :month_1
            diff_days <= 60 -> :month_2
            diff_days <= 90 -> :month_3
            # Fallback
            true -> :month_3
          end
        else
          # Fallback
          :month_1
        end

      current_month = Map.get(acc, month_key)

      updated_month = %{
        # Will calculate average later
        score: 0,
        count: current_month.count + 1,
        total: current_month.total + score
      }

      Map.put(acc, month_key, updated_month)
    end)
    |> Map.new(fn {k, v} ->
      avg_score = if v.count > 0, do: div(v.total, v.count), else: 0
      {k, %{v | score: avg_score}}
    end)
  end

  defp extract_date(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt)
  defp extract_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp extract_date(%Date{} = d), do: d
  defp extract_date(_), do: nil

  defp score_color(score) when score >= 80, do: "text-green-600"
  defp score_color(score) when score >= 60, do: "text-blue-600"
  defp score_color(score) when score >= 40, do: "text-amber-600"
  defp score_color(_), do: "text-red-600"

  defp score_bg_color(score) when score >= 80, do: "bg-green-50 border-green-200"
  defp score_bg_color(score) when score >= 60, do: "bg-blue-50 border-blue-200"
  defp score_bg_color(score) when score >= 40, do: "bg-amber-50 border-amber-200"
  defp score_bg_color(_), do: "bg-red-50 border-red-200"

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      phx-window-keydown="close"
      phx-key="Escape"
      phx-target={@myself}
    >
      <div
        class="bg-white rounded-xl shadow-2xl w-full max-w-5xl mx-4 max-h-[90vh] overflow-y-auto"
        phx-click-away="close"
        phx-target={@myself}
      >
        <!-- Header -->
        <div class="sticky top-0 bg-white border-b px-6 py-4 flex justify-between items-center z-10">
          <div>
            <h2 class="text-2xl font-bold text-gray-900">Evaluate Attachee</h2>
            <p class="text-sm text-gray-500 mt-1">
              {@attachee.user.username || @attachee.user.email}
            </p>
          </div>
          <button
            phx-click="close"
            phx-target={@myself}
            class="text-gray-400 hover:text-gray-600 text-3xl leading-none"
          >
            ×
          </button>
        </div>

        <.form
          :let={f}
          for={@changeset}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="p-6 space-y-8"
        >
          <!-- Total Score Display -->
          <div class={"rounded-xl p-6 border-2 #{score_bg_color(@calculated_score)}"}>
            <div class="text-center">
              <p class="text-sm font-medium text-gray-600 uppercase tracking-wide mb-2">
                Total Evaluation Score
              </p>
              <div class={"text-6xl font-bold #{score_color(@calculated_score)}"}>
                {@calculated_score}
              </div>
              <p class="text-xs text-gray-500 mt-2">
                Calculated from task performance (50%) and evaluation criteria (50%)
              </p>
            </div>
          </div>
          
    <!-- Task Scores Section -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-bold text-gray-900">Task Performance Evaluation</h3>
              <span class="text-sm text-gray-500 font-medium">Weight: 50%</span>
            </div>

            <%= if @tasks == [] do %>
              <div class="text-center py-8 bg-gray-50 rounded-lg border border-gray-200">
                <svg
                  class="w-12 h-12 mx-auto text-gray-300 mb-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                  />
                </svg>
                <p class="text-gray-500 text-sm">No tasks assigned to this attachee</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for task <- @tasks do %>
                  <div class={"border rounded-lg p-4 transition " <> if(task.rating, do: "border-green-200 bg-green-50", else: "border-gray-200 hover:bg-gray-50")}>
                    <div class="flex items-start justify-between gap-4 mb-3">
                      <div class="flex-1">
                        <div class="flex items-center gap-2">
                          <h4 class="font-semibold text-gray-900 text-sm">{task.title}</h4>
                          <%= if task.rating do %>
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                              <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                <path
                                  fill-rule="evenodd"
                                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                                  clip-rule="evenodd"
                                />
                              </svg>
                              Rated
                            </span>
                          <% end %>
                        </div>
                        <%= if task.description do %>
                          <p class="text-xs text-gray-500 mt-1 line-clamp-2">{task.description}</p>
                        <% end %>
                        <%= if task.rating do %>
                          <div class="mt-2 text-xs">
                            <span class="text-gray-600">Rating:</span>
                            <span class="font-semibold text-green-700 ml-1">
                              {TrialApp.Eams.Task.rating_label(task.rating)}
                            </span>
                          </div>
                        <% end %>
                      </div>
                      <span class={"text-2xl font-bold min-w-[60px] text-right " <> if(task.rating, do: "text-green-600", else: "text-purple-600")}>
                        {Map.get(@task_scores, task.id, 50)}
                      </span>
                    </div>

                    <%= if task.rating do %>
                      <!-- Read-only display for rated tasks -->
                      <div class="flex items-center gap-3 opacity-60">
                        <div class="flex-1 h-2 bg-green-200 rounded-lg relative overflow-hidden">
                          <div
                            class="absolute inset-y-0 left-0 bg-green-500 rounded-lg"
                            style={"width: #{Map.get(@task_scores, task.id, 50)}%"}
                          >
                          </div>
                        </div>
                        <div class="flex gap-1 text-xs text-gray-500">
                          <span>0</span>
                          <span class="mx-1">-</span>
                          <span>100</span>
                        </div>
                      </div>
                      <p class="text-xs text-green-700 mt-2 italic">
                        ✓ This task has been rated and cannot be changed
                      </p>
                    <% else %>
                      <!-- Editable slider for unrated tasks -->
                      <div class="flex items-center gap-3">
                        <input
                          type="range"
                          min="0"
                          max="100"
                          value={Map.get(@task_scores, task.id, 50)}
                          phx-change="update_task_score"
                          phx-target={@myself}
                          name={"task_score[#{task.id}]"}
                          class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-purple-600"
                        />
                        <div class="flex gap-1 text-xs text-gray-500">
                          <span>0</span>
                          <span class="mx-1">-</span>
                          <span>100</span>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          
    <!-- Evaluation Criteria Section -->
          <div class="space-y-4 pt-6 border-t-2 border-gray-200">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-bold text-gray-900">Performance Criteria</h3>
              <span class="text-sm text-gray-500 font-medium">Weight: 50%</span>
            </div>

            <div class="space-y-3">
              <%= for criteria <- @evaluation_criteria do %>
                <div class="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition">
                  <div class="flex items-start justify-between gap-4 mb-3">
                    <div class="flex-1">
                      <div class="flex items-center gap-2">
                        <h4 class="font-semibold text-gray-900 text-sm">{criteria.label}</h4>
                        <span class="text-xs text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full">
                          {criteria.weight}%
                        </span>
                      </div>
                    </div>
                    <span class="text-2xl font-bold text-blue-600 min-w-[60px] text-right">
                      {Map.get(@criteria_scores, criteria.key, 50)}
                    </span>
                  </div>

                  <div class="flex items-center gap-3">
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={Map.get(@criteria_scores, criteria.key, 50)}
                      phx-change="update_criteria_score"
                      phx-target={@myself}
                      name={"criteria_score[#{criteria.key}]"}
                      class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-blue-600"
                    />
                    <div class="flex gap-1 text-xs text-gray-500">
                      <span>0</span>
                      <span class="mx-1">-</span>
                      <span>100</span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Comments Section -->
          <div class="pt-6 border-t-2 border-gray-200">
            <label class="block mb-2">
              <span class="text-sm font-bold text-gray-900">
                Comments <span class="text-red-500">*</span>
              </span>
              <span class="text-xs text-gray-500 ml-2">Minimum 10 characters</span>
            </label>
            <textarea
              name="evaluation[comments]"
              rows="6"
              class={"w-full px-4 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 #{if @changeset.errors[:comments], do: "border-red-500", else: "border-gray-300"}"}
              placeholder="Provide detailed feedback on the attachee's performance, strengths, and areas for improvement..."
              phx-debounce="500"
            ><%= Phoenix.HTML.Form.input_value(f, :comments) %></textarea>
            <%= if error = Keyword.get(@changeset.errors, :comments) do %>
              <p class="text-red-500 text-sm mt-1">
                {translate_error(error)}
              </p>
            <% end %>
          </div>
          
    <!-- Scoring Breakdown Summary -->
          <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
            <h4 class="font-semibold text-gray-900 text-sm mb-3">Score Breakdown</h4>
            <div class="grid grid-cols-2 gap-4 text-sm mb-4">
              <div>
                <span class="text-gray-600">Task Performance (50%):</span>
                <span class="font-bold text-purple-600 ml-2">
                  <%= if map_size(@task_scores) > 0 do %>
                    {Float.round(
                      (@task_scores |> Map.values() |> Enum.sum()) / map_size(@task_scores),
                      1
                    )}
                  <% else %>
                    50.0
                  <% end %>
                </span>
              </div>
              <div>
                <span class="text-gray-600">Criteria Performance (50%):</span>
                <span class="font-bold text-blue-600 ml-2">
                  {Float.round(
                    @evaluation_criteria
                    |> Enum.map(fn c -> Map.get(@criteria_scores, c.key, 50) * c.weight / 100 end)
                    |> Enum.sum(),
                    1
                  )}
                </span>
              </div>
            </div>
            
    <!-- Monthly Breakdown Preview -->
            <% monthly_data = calculate_monthly_data(@tasks, @task_scores, @attachee.starts_on) %>
            <div class="border-t border-gray-200 pt-3">
              <h5 class="text-xs font-bold text-gray-500 uppercase mb-2">
                Monthly Performance Preview
              </h5>
              <div class="grid grid-cols-3 gap-2">
                <div class="bg-white p-2 rounded border text-center">
                  <div class="text-xs text-gray-500">Month 1</div>
                  <div class="font-bold text-purple-600">{monthly_data.month_1.score}</div>
                  <div class="text-[10px] text-gray-400">{monthly_data.month_1.count} tasks</div>
                </div>
                <div class="bg-white p-2 rounded border text-center">
                  <div class="text-xs text-gray-500">Month 2</div>
                  <div class="font-bold text-purple-600">{monthly_data.month_2.score}</div>
                  <div class="text-[10px] text-gray-400">{monthly_data.month_2.count} tasks</div>
                </div>
                <div class="bg-white p-2 rounded border text-center">
                  <div class="text-xs text-gray-500">Month 3</div>
                  <div class="font-bold text-purple-600">{monthly_data.month_3.score}</div>
                  <div class="text-[10px] text-gray-400">{monthly_data.month_3.count} tasks</div>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Action Buttons -->
          <div class="flex justify-end gap-3 pt-6 border-t border-gray-200">
            <button
              type="button"
              phx-click="close"
              phx-target={@myself}
              class="px-6 py-2 text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition font-medium"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition font-medium disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={@submitting}
            >
              {if @submitting, do: "Submitting...", else: "Submit Evaluation"}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  # Helper function to convert rating to score
  defp rating_to_score(rating) do
    case rating do
      "exceeds_expectations" -> 100
      "meets_expectations" -> 80
      "average" -> 60
      "below_average" -> 40
      "poor" -> 20
      _ -> 50
    end
  end
end
