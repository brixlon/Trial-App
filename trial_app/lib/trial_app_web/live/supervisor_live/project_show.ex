defmodule TrialAppWeb.SupervisorLive.ProjectShow do
  use TrialAppWeb, :live_view
  alias TrialApp.Eams
  alias TrialApp.Eams.Task

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Load project with all details
    project =
      Eams.get_project!(id, %{preloads: [:program, :department, :organization, :supervisor]})

    # Verify supervisor owns this project (or is admin)
    if project.supervisor_id != current_user.id and "admin" not in current_user.roles do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to view this project")
       |> redirect(to: ~p"/supervisor/projects")}
    else
      # Load project attachees (includes those assigned to tasks)
      attachees = Eams.list_attachees_by_project(id)

      # Load project tasks
      tasks = Eams.list_tasks(%{filters: %{project_id: id}, preloads: [assignee: :user]})

      {:ok,
       socket
       |> assign(:page_title, project.name)
       |> assign(:project, project)
       |> assign(:attachees, attachees)
       |> assign(:tasks, tasks)
       |> assign(:active_tab, "attachees")
       |> assign(:show_add_attachee_modal, false)
       |> assign(:show_create_task_modal, false)
       |> assign(:all_attachees, [])
       |> assign(:attachee_search, "")
       |> assign(:task_changeset, Task.changeset(%Task{}, %{}))}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("open_add_attachee_modal", _params, socket) do
    # Load all attachees from system with user preload
    all_attachees = Eams.list_attachees(%{preloads: [:user, :department, :organization]})

    {:noreply,
     socket
     |> assign(:show_add_attachee_modal, true)
     |> assign(:all_attachees, all_attachees)
     |> assign(:attachee_search, "")}
  end

  def handle_event("close_add_attachee_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_attachee_modal, false)
     |> assign(:all_attachees, [])
     |> assign(:attachee_search, "")}
  end

  def handle_event("search_attachees", %{"value" => query}, socket) do
    {:noreply, assign(socket, :attachee_search, query)}
  end

  def handle_event("add_attachee", %{"attachee-id" => attachee_id}, socket) do
    project_id = socket.assigns.project.id

    case Eams.add_attachee_to_project(project_id, String.to_integer(attachee_id)) do
      {:ok, _} ->
        # Reload attachees
        attachees = Eams.list_attachees_by_project(project_id)

        {:noreply,
         socket
         |> assign(:attachees, attachees)
         |> assign(:show_add_attachee_modal, false)
         |> put_flash(:info, "Attachee added to project successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add attachee")}
    end
  end

  def handle_event("remove_attachee", %{"attachee-id" => attachee_id}, socket) do
    project_id = socket.assigns.project.id

    case Eams.remove_attachee_from_project(project_id, String.to_integer(attachee_id)) do
      {:ok, _} ->
        # Reload attachees
        attachees = Eams.list_attachees_by_project(project_id)

        {:noreply,
         socket
         |> assign(:attachees, attachees)
         |> put_flash(:info, "Attachee removed from project")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove attachee")}
    end
  end

  def handle_event("open_create_task_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_task_modal, true)}
  end

  def handle_event("close_create_task_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_task_modal, false)
     |> assign(:task_changeset, Task.changeset(%Task{}, %{}))}
  end

  def handle_event("create_task", %{"task" => task_params}, socket) do
    params =
      task_params
      |> Map.put("project_id", socket.assigns.project.id)

    case Eams.create_task(params) do
      {:ok, _task} ->
        # Reload tasks
        tasks =
          Eams.list_tasks(%{
            filters: %{project_id: socket.assigns.project.id},
            preloads: [assignee: :user]
          })

        {:noreply,
         socket
         |> assign(:tasks, tasks)
         |> assign(:show_create_task_modal, false)
         |> assign(:task_changeset, Task.changeset(%Task{}, %{}))
         |> put_flash(:info, "Task created successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :task_changeset, changeset)}
    end
  end

  def handle_event("delete_task", %{"task-id" => task_id}, socket) do
    task = Eams.get_task!(task_id)

    case Eams.delete_task(task) do
      {:ok, _} ->
        # Reload tasks
        tasks =
          Eams.list_tasks(%{
            filters: %{project_id: socket.assigns.project.id},
            preloads: [assignee: :user]
          })

        {:noreply,
         socket
         |> assign(:tasks, tasks)
         |> put_flash(:info, "Task deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete task")}
    end
  end

  # Helper to filter attachees by search query
  defp filter_attachees(attachees, ""), do: attachees

  defp filter_attachees(attachees, query) do
    q = String.downcase(query)

    Enum.filter(attachees, fn attachee ->
      name = attachee.user.username || attachee.user.email
      String.contains?(String.downcase(name), q)
    end)
  end

  # Helper to get available attachees (not already in project)
  defp available_attachees(all_attachees, project_attachees) do
    project_ids = Enum.map(project_attachees, & &1.id)
    Enum.reject(all_attachees, fn a -> a.id in project_ids end)
  end

  # Helper for task status badge color
  defp task_status_color("pending"), do: "bg-gray-100 text-gray-700"
  defp task_status_color("in_progress"), do: "bg-blue-100 text-blue-700"
  defp task_status_color("submitted"), do: "bg-yellow-100 text-yellow-700"
  defp task_status_color("rejected"), do: "bg-red-100 text-red-700"
  defp task_status_color("completed"), do: "bg-green-100 text-green-700"
  defp task_status_color(_), do: "bg-gray-100 text-gray-700"

  # Helper for project status badge class
  defp status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("active"), do: "bg-green-100 text-green-800"
  defp status_badge_class("rejected"), do: "bg-red-100 text-red-800"
  defp status_badge_class("completed"), do: "bg-blue-100 text-blue-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
