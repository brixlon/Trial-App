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

  # Helper to convert rating to score
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
