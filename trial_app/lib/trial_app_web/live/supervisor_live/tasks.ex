defmodule TrialAppWeb.SupervisorLive.Tasks do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    active_role = Accounts.get_active_role(current_user)

    {all_tasks, projects} = case active_role do
      "admin" ->
        {Eams.list_tasks(%{preloads: [:project, task_evaluations: :evaluator, assignee: :user]}),
         Eams.list_projects(%{preloads: [:program, :department, :organization]})}
      _ ->
        tasks = Eams.list_tasks_for_supervisor(current_user.id)
        tasks_with_preloads = TrialApp.Repo.preload(tasks, [:project, task_evaluations: :evaluator, assignee: :user])
        {tasks_with_preloads, Eams.list_projects_for_supervisor(current_user.id)}
    end

    pending_evaluation = Enum.filter(all_tasks, &is_pending_evaluation?/1)
    overdue_tasks = get_overdue_tasks(all_tasks)
    tasks_by_project = Enum.group_by(all_tasks, & &1.project_id)

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:active_role, active_role)
     |> assign(:all_tasks, all_tasks)
     |> assign(:projects, projects)
     |> assign(:pending_evaluation, pending_evaluation)
     |> assign(:overdue_tasks, overdue_tasks)
     |> assign(:tasks_by_project, tasks_by_project)
     |> assign(:selected_tab, "all")
     |> assign(:selected_task, nil)
     |> assign(:selected_task_evaluation, nil)
     |> assign(:show_task_modal, false)
     |> assign(:show_evaluate_modal, false)
     |> assign(:evaluation_rating, nil)
     |> assign(:evaluation_comments, "")
     |> assign(:page_title, "Tasks Management")}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  def handle_event("view_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id, %{preloads: [:project, task_evaluations: :evaluator, assignee: :user]})

    # Get evaluation if exists
    evaluation = get_latest_evaluation(task)

    {:noreply,
     socket
     |> assign(:selected_task, task)
     |> assign(:selected_task_evaluation, evaluation)
     |> assign(:show_task_modal, true)}
  rescue
    e ->
      IO.inspect(e, label: "Error loading task")
      {:noreply, put_flash(socket, :error, "Failed to load task")}
  end

  def handle_event("open_evaluate_modal", %{"id" => id}, socket) do
    task = Eams.get_task!(id, %{preloads: [:project, task_evaluations: :evaluator, assignee: :user]})
    {:noreply,
     socket
     |> assign(:selected_task, task)
     |> assign(:show_task_modal, false)
     |> assign(:show_evaluate_modal, true)
     |> assign(:evaluation_rating, nil)
     |> assign(:evaluation_comments, "")}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_task, nil)
     |> assign(:selected_task_evaluation, nil)
     |> assign(:show_task_modal, false)
     |> assign(:show_evaluate_modal, false)
     |> assign(:evaluation_rating, nil)
     |> assign(:evaluation_comments, "")}
  end

  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_rating", %{"rating" => rating}, socket) do
    rating_int = String.to_integer(rating)
    {:noreply, assign(socket, :evaluation_rating, rating_int)}
  end

  def handle_event("submit_evaluation", %{"comment" => comment}, socket) do
    task = socket.assigns.selected_task
    rating = socket.assigns.evaluation_rating

    cond do
      is_nil(task) ->
        {:noreply, put_flash(socket, :error, "Task not found")}

      is_nil(rating) ->
        {:noreply, put_flash(socket, :error, "Please select a rating before submitting")}

      is_nil(task.assignee_id) ->
        {:noreply, put_flash(socket, :error, "Task assignee information is missing")}

      String.length(comment || "") < 10 ->
        {:noreply, put_flash(socket, :error, "Comments must be at least 10 characters long")}

      true ->
        submit_evaluation_internal(socket, task, rating, comment)
    end
  end

  def handle_event("submit_evaluation", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please provide evaluation details")}
  end

  defp submit_evaluation_internal(socket, task, rating, comment) do
    score = rating * 20

    evaluation_params = %{
      task_id: task.id,
      attachee_id: task.assignee_id,
      evaluator_id: socket.assigns.current_user.id,
      score: score,
      comments: comment || ""
    }

    user_scope = %{id: socket.assigns.current_user.id}

    case Eams.create_task_evaluation(evaluation_params, user_scope) do
      {:ok, _evaluation} ->
        case Eams.update_task(task, %{status: "completed"}) do
          {:ok, _updated_task} ->
            {:noreply,
             socket
             |> put_flash(:info, "Task evaluated successfully!")
             |> assign(:show_evaluate_modal, false)
             |> assign(:selected_task, nil)
             |> assign(:evaluation_rating, nil)
             |> assign(:evaluation_comments, "")
             |> reload_tasks()}

          {:error, changeset} ->
            IO.inspect(changeset, label: "Error updating task")
            {:noreply, put_flash(socket, :error, "Evaluation saved but failed to update task status")}
        end

      {:error, changeset} ->
        errors = changeset_errors_to_string(changeset)
        {:noreply, put_flash(socket, :error, "Failed to submit evaluation: #{errors}")}
    end
  rescue
    e ->
      IO.inspect(e, label: "Exception occurred")
      {:noreply, put_flash(socket, :error, "An unexpected error occurred")}
  end

  defp changeset_errors_to_string(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  @impl true
  def handle_info({:switch_role, new_role}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.switch_user_role(user, new_role) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        redirect_path = case new_role do
          "admin" -> ~p"/admin/dashboard"
          "supervisor" -> ~p"/supervisor/dashboard"
          "attachee" -> ~p"/attachee"
          "employee" -> ~p"/dashboard"
          _ -> ~p"/dashboard"
        end

        {:noreply,
         socket
         |> assign(:current_scope, updated_scope)
         |> push_navigate(to: redirect_path)}

      {:error, :unauthorized_role} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to switch to that role")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end

  defp reload_tasks(socket) do
    try do
      current_user = socket.assigns.current_user
      active_role = socket.assigns.active_role

      all_tasks = case active_role do
        "admin" ->
          Eams.list_tasks(%{preloads: [:project, task_evaluations: :evaluator, assignee: :user]})
        _ ->
          tasks = Eams.list_tasks_for_supervisor(current_user.id)
          TrialApp.Repo.preload(tasks, [:project, task_evaluations: :evaluator, assignee: :user])
      end

      pending_evaluation = Enum.filter(all_tasks, &is_pending_evaluation?/1)
      overdue_tasks = get_overdue_tasks(all_tasks)
      tasks_by_project = Enum.group_by(all_tasks, & &1.project_id)

      socket
      |> assign(:all_tasks, all_tasks)
      |> assign(:pending_evaluation, pending_evaluation)
      |> assign(:overdue_tasks, overdue_tasks)
      |> assign(:tasks_by_project, tasks_by_project)
    rescue
      e ->
        IO.inspect(e, label: "Error in reload_tasks")
        socket
    end
  end

  defp get_overdue_tasks(tasks) do
    today = Date.utc_today()
    Enum.filter(tasks, fn task ->
      task.due_on && Date.compare(task.due_on, today) == :lt && task.status not in ["completed", "submitted"]
    end)
  end

  defp is_overdue?(task) do
    task.due_on && Date.compare(task.due_on, Date.utc_today()) == :lt && task.status not in ["completed"]
  end

  defp days_overdue(task) do
    if task.due_on do
      Date.diff(Date.utc_today(), task.due_on)
    else
      0
    end
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("in_progress"), do: "bg-blue-100 text-blue-800"
  defp status_color("submitted"), do: "bg-purple-100 text-purple-800"
  defp status_color("completed"), do: "bg-green-100 text-green-800"
  defp status_color("rejected"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_latest_evaluation(task) do
    case task.task_evaluations do
      %Ecto.Association.NotLoaded{} -> nil
      nil -> nil
      [] -> nil
      evaluations when is_list(evaluations) ->
        evaluations
        |> Enum.filter(fn eval -> eval.inserted_at != nil end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> List.first()
    end
  end

  defp is_pending_evaluation?(task) do
    task.status == "submitted" &&
      case task.task_evaluations do
        %Ecto.Association.NotLoaded{} -> true
        nil -> true
        [] -> true
        evaluations when is_list(evaluations) -> false
        _ -> false
      end
  end
end
