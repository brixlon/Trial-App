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

    # Initialize task scores
    task_scores = Map.new(tasks, fn task -> {task.id, 50} end)

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

      # Create main/overall evaluation (without task_id)
      main_params = %{
        "attachee_id" => socket.assigns.attachee.id,
        "evaluator_id" => socket.assigns.current_user.id,
        "score" => rounded_score,
        "comments" => params["comments"],
        "evaluation_details" => Jason.encode!(evaluation_details)
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

  defp score_color(score) when score >= 80, do: "text-green-600"
  defp score_color(score) when score >= 60, do: "text-blue-600"
  defp score_color(score) when score >= 40, do: "text-amber-600"
  defp score_color(_), do: "text-red-600"

  defp score_bg_color(score) when score >= 80, do: "bg-green-50 border-green-200"
  defp score_bg_color(score) when score >= 60, do: "bg-blue-50 border-blue-200"
  defp score_bg_color(score) when score >= 40, do: "bg-amber-50 border-amber-200"
  defp score_bg_color(_), do: "bg-red-50 border-red-200"

end
