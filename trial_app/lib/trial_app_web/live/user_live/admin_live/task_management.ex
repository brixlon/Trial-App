defmodule TrialAppWeb.AdminLive.TaskManagement do
  use TrialAppWeb, :live_view
  require Logger
  import Ecto.Query

  alias TrialApp.{Eams, Repo}

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("TaskManagement LiveView mounted")

    {:ok,
     socket
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})
     |> assign(:tasks, list_tasks_safe())
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_task, nil)
     |> assign(:viewing_task, nil)
     |> assign(:projects, Eams.list_projects() |> Repo.preload(:program))
     |> assign(:attachees, [])
     |> assign(:filter_status, "all")
     |> assign(:form_data, %{
       "title" => "",
       "description" => "",
       "project_id" => "",
       "assignee_id" => "",
       "due_on" => "",
       "status" => "pending"
     })
     |> assign(:errors, %{})}
  end

  # --------------------------------------------------------------------- #
  # EVENT HANDLERS
  # --------------------------------------------------------------------- #

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_task, nil)
     |> assign(:form_data, %{
       "title" => "",
       "description" => "",
       "project_id" => "",
       "assignee_id" => "",
       "due_on" => "",
       "status" => "pending"
     })
     |> assign(:attachees, [])
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_task, nil)
     |> assign(:viewing_task, nil)
     |> assign(:errors, %{})
     |> assign(:attachees, [])
     |> assign(:form_data, %{
       "title" => "",
       "description" => "",
       "project_id" => "",
       "assignee_id" => "",
       "due_on" => "",
       "status" => "pending"
     })}
  end

  @impl true
  def handle_event("view_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id) |> Repo.preload([:project, assignee: [:user]])
    {:noreply,
     socket
     |> assign(:viewing_task, task)
     |> assign(:show_view_modal, true)}
  end

  @impl true
  def handle_event("edit_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id) |> Repo.preload([:project, assignee: [:user]])

    form_data = %{
      "title" => task.title || "",
      "description" => task.description || "",
      "project_id" => to_string(task.project_id || ""),
      "assignee_id" => to_string(task.assignee_id || ""),
      "due_on" => (if task.due_on, do: Date.to_iso8601(task.due_on), else: ""),
      "status" => task.status || "pending"
    }

    # Load attachees based on the task's project
    attachees = if task.project_id do
      load_attachees_safe_via_project(task.project_id)
    else
      []
    end

    Logger.debug("Loaded #{length(attachees)} attachees for editing task")

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_task, task)
     |> assign(:form_data, form_data)
     |> assign(:attachees, attachees)
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_event("delete_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id)

    case Eams.delete_task(task) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:tasks, list_tasks_safe())
         |> put_flash(:info, "Task deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete task")}
    end
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  @impl true
  def handle_event("update_form", %{"task" => params}, socket) do
    Logger.debug("Form update params: #{inspect(params)}")

    # Check if project changed and load attachees
    project_id = Map.get(params, "project_id")

    attachees = if project_id != "" and project_id != nil do
      project_int = safe_int(project_id)
      if project_int do
        load_attachees_safe_via_project(project_int)
      else
        []
      end
    else
      []
    end

    # Merge all params including status
    updated_form_data = Map.merge(socket.assigns.form_data, params)

    Logger.debug("Updated form data: #{inspect(updated_form_data)}")
    Logger.debug("Loaded #{length(attachees)} attachees")

    {:noreply,
     socket
     |> assign(:form_data, updated_form_data)
     |> assign(:attachees, attachees)}
  end

  @impl true
  def handle_event("save", %{"task" => params}, socket) do
    Logger.info("Saving task with params: #{inspect(params)}")

    # Build base attributes
    attrs = %{
      title: params["title"],
      description: params["description"] || "",
      due_on: parse_date(params["due_on"]),
      project_id: parse_int(params["project_id"]),
      assignee_id: parse_int(params["assignee_id"])
    }

    # Determine status
    attrs = if socket.assigns.editing_task do
      # When editing, use the provided status or default to current
      status = params["status"] || socket.assigns.editing_task.status || "pending"
      Map.put(attrs, :status, status)
    else
      # When creating, set status based on assignee
      status = if attrs.assignee_id, do: "in_progress", else: "pending"
      Map.put(attrs, :status, status)
    end

    Logger.info("Final attributes: #{inspect(attrs)}")

    result = if socket.assigns.editing_task do
      Eams.update_task(socket.assigns.editing_task, attrs)
    else
      Eams.create_task(attrs)
    end

    case result do
      {:ok, task} ->
        Logger.info("Task saved successfully: #{inspect(task)}")
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:editing_task, nil)
         |> assign(:errors, %{})
         |> assign(:attachees, [])
         |> assign(:form_data, %{
           "title" => "",
           "description" => "",
           "project_id" => "",
           "assignee_id" => "",
           "due_on" => "",
           "status" => "pending"
         })
         |> assign(:tasks, list_tasks_safe())
         |> put_flash(:info, "Task #{if socket.assigns.editing_task, do: "updated", else: "created"} successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to save task. Changeset errors: #{inspect(changeset.errors)}")
        errors = changeset.errors |> Enum.map(fn {f, {m, _}} -> {f, m} end) |> Enum.into(%{})
        {:noreply, assign(socket, :errors, errors)}
    end
  end

  # --------------------------------------------------------------------- #
  # HELPERS
  # --------------------------------------------------------------------- #

  defp list_tasks_safe do
    try do
      Eams.list_tasks() |> Repo.preload([:project, assignee: [:user]])
    rescue
      e ->
        Logger.error("Error listing tasks: #{inspect(e)}")
        []
    end
  end

  # FIXED: Use Eams.list_attachees_in_program
  defp load_attachees_safe_via_project(project_id) when is_integer(project_id) do
    try do
      # First get the project with its program preloaded
      project = Eams.get_project!(project_id) |> Repo.preload(:program)
      Logger.debug("Project loaded: #{inspect(project.id)}, Program ID: #{inspect(project.program_id)}")

      cond do
        # If project has a program, get attachees enrolled in that program
        project.program_id ->
          attachees = Eams.list_attachees_by_program(project.program_id, %{preloads: [:user]})
          Logger.debug("Found #{length(attachees)} attachees for program #{project.program_id}")
          attachees

        # If project has a department, get all attachees in that department
        project.department_id ->
          Logger.debug("Project has no program, trying department #{project.department_id}")
          query = from a in TrialApp.Eams.Attachee,
            where: a.department_id == ^project.department_id and a.status == "active",
            preload: [:user]
          attachees = Repo.all(query)
          Logger.debug("Found #{length(attachees)} attachees in department")
          attachees

        # Otherwise return all active attachees
        true ->
          Logger.debug("Project has no program_id or department_id, loading all active attachees")
          load_all_active_attachees()
      end
    rescue
      e ->
        Logger.error("Error loading attachees for project #{project_id}: #{inspect(e)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        []
    end
  end
  defp load_attachees_safe_via_project(_), do: []

  defp load_all_active_attachees do
    try do
      query = from a in TrialApp.Eams.Attachee,
        where: a.status == "active",
        preload: [:user],
        order_by: [asc: a.id]

      attachees = Repo.all(query)
      Logger.debug("Loaded #{length(attachees)} active attachees")
      attachees
    rescue
      e ->
        Logger.error("Error loading all active attachees: #{inspect(e)}")
        []
    end
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(""), do: nil
  defp safe_int(nil), do: nil
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end

  # Improved date parsing function that handles dates across years
  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(_), do: nil

  # --- Attachee Name & Initials ---
  defp get_attachee_name(%{first_name: fnm, last_name: lnm}) when is_binary(fnm) and is_binary(lnm) do
    "#{fnm} #{lnm}"
  end
  defp get_attachee_name(%{user: %{username: un}}) when is_binary(un), do: un
  defp get_attachee_name(%{user: %{email: em}}) when is_binary(em), do: em
  defp get_attachee_name(_), do: "Attachee"

  defp initials(%{first_name: fnm, last_name: lnm}) when is_binary(fnm) and is_binary(lnm) do
    "#{String.first(fnm)}#{String.first(lnm)}" |> String.upcase()
  end
  defp initials(%{user: %{username: un}}) when is_binary(un) do
    un |> String.slice(0..1) |> String.upcase()
  end
  defp initials(_), do: "A"

  # --- Status & Due Date ---
  defp status_color("pending"), do: "bg-yellow-50 text-yellow-700"
  defp status_color("in_progress"), do: "bg-blue-50 text-blue-700"
  defp status_color("blocked"), do: "bg-red-50 text-red-700"
  defp status_color("submitted"), do: "bg-indigo-50 text-indigo-700"
  defp status_color("completed"), do: "bg-emerald-50 text-emerald-700"
  defp status_color("cancelled"), do: "bg-gray-50 text-gray-700"
  defp status_color(_), do: "bg-gray-50 text-gray-700"

  defp status_label(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp due_date_badge(date) do
    today = Date.utc_today()
    diff = Date.diff(date, today)

    cond do
      diff < 0 -> {"bg-red-100 text-red-800", "Overdue"}
      diff == 0 -> {"bg-orange-100 text-orange-800", "Due Today"}
      diff == 1 -> {"bg-yellow-100 text-yellow-800", "Tomorrow"}
      diff <= 3 -> {"bg-amber-100 text-amber-800", "Soon"}
      true -> {"bg-gray-100 text-gray-700", "Later"}
    end
  end

  defp filtered_tasks(tasks, "all"), do: tasks
  defp filtered_tasks(tasks, status), do: Enum.filter(tasks, &(&1.status == status))

  defp total_tasks(tasks), do: length(tasks)
  defp active_tasks(tasks), do: Enum.count(tasks, &(&1.status == "pending" || &1.status == "in_progress"))
  defp in_progress_tasks(tasks), do: Enum.count(tasks, &(&1.status == "in_progress"))
  defp completed_tasks(tasks), do: Enum.count(tasks, &(&1.status == "completed"))
end
  