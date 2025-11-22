defmodule TrialAppWeb.AdminLive.AttacheeManagementShow do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialAppWeb.BreadcrumbComponent

  # Mount for STANDALONE attachee management view
  def mount(%{"id" => id}, _session, socket) do
    attachee = Eams.get_attachee_with_details(String.to_integer(id))

    projects = Eams.list_projects_by_attachee(attachee.id)
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
     |> assign(:projects, projects)
     |> assign(:tasks, tasks)
     |> assign(:evaluations, evaluations)
     |> assign(:stats, stats)
     |> assign(:eval_summary, eval_summary)
     |> assign(:breadcrumbs, breadcrumbs)
     |> assign(:page_title, attachee_name(attachee))
     |> assign(:show_eval_modal, false)
     |> assign(:show_task_eval_modal, false)
     |> assign(:viewing_evaluation, nil)
     |> assign(:viewing_task_evaluation, nil)
     |> assign(:selected_task, nil)
     |> assign(:eval_form, %{"score" => "", "comments" => ""})
     |> assign(:task_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:eval_errors, %{})
     |> assign(:task_eval_errors, %{})
     |> assign(:active_tab, "overview")
     |> assign(:selected_project, nil)
     |> assign(:expanded_projects, %{})
     |> assign(:expanded_task_evals, %{})
     |> assign(:show_success_toast, false)
     |> assign(:show_error_toast, false)
     |> assign(:success_message, "")
     |> assign(:error_message, "")
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})}
  end

  # Tab switching
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Project selection for filtering
  def handle_event("select_project", %{"project_id" => project_id}, socket) do
    selected_project = if project_id == "", do: nil, else: String.to_integer(project_id)
    {:noreply, assign(socket, :selected_project, selected_project)}
  end

  # Toggle project tasks expansion
  def handle_event("toggle_project_tasks", %{"id" => project_id}, socket) do
    project_id = if is_binary(project_id), do: String.to_integer(project_id), else: project_id
    expanded = socket.assigns.expanded_projects

    new_expanded =
      if Map.get(expanded, project_id, false) do
        Map.put(expanded, project_id, false)
      else
        Map.put(expanded, project_id, true)
      end

    {:noreply, assign(socket, :expanded_projects, new_expanded)}
  end

  # Toggle task evaluations expansion
  def handle_event("toggle_task_evals", %{"id" => task_id}, socket) do
    task_id = String.to_integer(task_id)
    expanded = socket.assigns.expanded_task_evals

    new_expanded =
      if Map.get(expanded, task_id, false) do
        Map.put(expanded, task_id, false)
      else
        Map.put(expanded, task_id, true)
      end

    {:noreply, assign(socket, :expanded_task_evals, new_expanded)}
  end

  # General Evaluation modal (for overall attachee)
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
         |> assign(:active_tab, "evaluations")
         |> show_success_toast("Evaluation submitted successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> {field, msg} end)
          |> Enum.into(%{})

        {:noreply, assign(socket, :eval_errors, errors)}
    end
  end

  # Task Evaluation modal
  def handle_event("open_task_eval_modal", %{"id" => task_id}, socket) do
    task = Eams.get_task!(String.to_integer(task_id))

    {:noreply,
     socket
     |> assign(:show_task_eval_modal, true)
     |> assign(:selected_task, task)
     |> assign(:task_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:task_eval_errors, %{})}
  end

  def handle_event("close_task_eval_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_task_eval_modal, false)
     |> assign(:selected_task, nil)
     |> assign(:task_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:task_eval_errors, %{})}
  end

  def handle_event("update_task_eval_form", %{"eval" => params}, socket) do
    {:noreply, assign(socket, :task_eval_form, params)}
  end

  def handle_event("submit_task_evaluation", %{"eval" => params}, socket) do
    attrs = %{
      score: parse_int(params["score"]),
      comments: params["comments"],
      task_id: socket.assigns.selected_task.id,
      attachee_id: socket.assigns.attachee.id,
      evaluator_id: socket.assigns.current_scope.id
    }

    case Eams.create_task_evaluation(attrs, socket.assigns.current_scope) do
      {:ok, _task_evaluation} ->
        tasks = Eams.list_tasks_by_attachee(socket.assigns.attachee.id)

        {:noreply,
         socket
         |> assign(:tasks, tasks)
         |> assign(:show_task_eval_modal, false)
         |> assign(:selected_task, nil)
         |> assign(:task_eval_form, %{"score" => "", "comments" => ""})
         |> assign(:task_eval_errors, %{})
         |> show_success_toast("Task evaluation submitted successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> {field, msg} end)
          |> Enum.into(%{})

        {:noreply, assign(socket, :task_eval_errors, errors)}
    end
  end

  # View evaluation details
  def handle_event("view_evaluation", %{"id" => id}, socket) do
    evaluation =
      Eams.get_evaluation!(String.to_integer(id))
      |> TrialApp.Repo.preload([:evaluator])

    {:noreply, assign(socket, :viewing_evaluation, evaluation)}
  end

  def handle_event("close_eval_view", _params, socket) do
    {:noreply, assign(socket, :viewing_evaluation, nil)}
  end

  # View task evaluation details
  def handle_event("view_task_evaluation", %{"id" => id}, socket) do
    task_evaluation =
      Eams.get_task_evaluation!(String.to_integer(id))
      |> TrialApp.Repo.preload([:evaluator, :task])

    {:noreply, assign(socket, :viewing_task_evaluation, task_evaluation)}
  end

  def handle_event("close_task_eval_view", _params, socket) do
    {:noreply, assign(socket, :viewing_task_evaluation, nil)}
  end

  # Toast notifications
  def handle_event("close_toast", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_success_toast, false)
     |> assign(:show_error_toast, false)
     |> assign(:success_message, "")
     |> assign(:error_message, "")}
  end

  # Helper functions
  defp show_success_toast(socket, message) do
    socket
    |> assign(:show_success_toast, true)
    |> assign(:success_message, message)
    |> assign(:show_error_toast, false)
  end

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

  defp project_status_color(status) do
    case status do
      "completed" -> "bg-green-100 text-green-800"
      "active" -> "bg-blue-100 text-blue-800"
      "on_hold" -> "bg-amber-100 text-amber-800"
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

  defp filtered_tasks(tasks, nil), do: tasks

  defp filtered_tasks(tasks, project_id) do
    Enum.filter(tasks, fn task ->
      Ecto.assoc_loaded?(task.project) && task.project && task.project.id == project_id
    end)
  end

  defp task_evaluations_count(task) do
    if Ecto.assoc_loaded?(task.task_evaluations) && is_list(task.task_evaluations) do
      length(task.task_evaluations)
    else
      0
    end
  end

  defp task_average_score(task) do
    if Ecto.assoc_loaded?(task.task_evaluations) && is_list(task.task_evaluations) &&
         length(task.task_evaluations) > 0 do
      scores = Enum.map(task.task_evaluations, & &1.score)
      avg = Enum.sum(scores) / length(scores)
      Float.round(avg, 1)
    else
      nil
    end
  end

  # Safe helper to get project tasks
  defp get_project_tasks(tasks, project_id) do
    Enum.filter(tasks, fn task ->
      case task do
        %{project: %{id: ^project_id}} -> true
        _ -> false
      end
    end)
  end

  # Safe helper to count completed tasks
  defp count_completed_tasks(tasks) do
    Enum.count(tasks, fn task -> task.status == "completed" end)
  end

  # Safe helper to calculate completion percentage
  defp calculate_completion_percentage(completed, total) when total > 0 do
    Float.round(completed / total * 100, 0)
  end

  defp calculate_completion_percentage(_, _), do: 0
end
