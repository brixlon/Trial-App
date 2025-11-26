defmodule TrialAppWeb.SupervisorLive.Dashboard do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams, Orgs}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    current_scope = socket.assigns.current_scope
    active_role = Accounts.get_active_role(current_user)

    # Subscribe to task updates for real-time activity feed
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TrialApp.PubSub, "tasks")
      # Schedule periodic refresh every 30 seconds as fallback
      schedule_activity_refresh()
    end

    {:ok,
     socket
     |> assign(:page_title, "Supervisor Dashboard")
     |> assign(:current_user, current_user)
     |> assign(:current_scope, current_scope)
     |> assign(:active_role, active_role)
     |> assign(:selected_project, nil)
     |> assign(:project_tasks, [])
     |> assign(:show_task_form, false)
     |> load_data(current_user, active_role)}
  end

  # FIXED: Admin load_data - ensure we're loading ALL projects
  defp load_data(socket, user, "admin") do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)

    # Admin sees ALL projects with proper preloads
    projects = Eams.list_projects(%{preloads: [:program, :department, :organization]})

    # Admin sees ALL tasks with proper preloads
    all_tasks = Eams.list_tasks(%{preloads: [:project, assignee: :user]})

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats_for_admin(all_tasks))
    |> assign(:recent_activities, load_recent_activities_for_admin(all_tasks))
  end

  # FIXED: Supervisor load_data - only their assigned projects
  defp load_data(socket, user, _role) do
    org = Orgs.get_organization_for_user(user.id)
    dept = Orgs.get_department_for_user(user.id)

    # Supervisor sees only their own projects (where they are the supervisor)
    projects = Eams.list_projects_for_supervisor(user.id)

    # Supervisor sees only tasks from their projects
    all_tasks = Eams.list_tasks_for_supervisor(user.id)

    socket
    |> assign(:organization, org)
    |> assign(:department, dept)
    |> assign(:projects, projects)
    |> assign(:stats, load_supervisor_stats(all_tasks))
    |> assign(:recent_activities, load_recent_activities(all_tasks))
  end

  # Admin stats helper
  defp load_supervisor_stats_for_admin(all_tasks) do
    %{
      total_projects: Eams.count_projects(),
      total_attachees: Eams.count_attachees(),
      active_tasks: Enum.count(all_tasks, &(&1.status in ["pending", "in_progress"])),
      pending_reviews: Enum.count(all_tasks, &(&1.status == "submitted")),
      completed_tasks: Enum.count(all_tasks, &(&1.status == "completed"))
    }
  end

  # Supervisor stats helper
  defp load_supervisor_stats(all_tasks) do
    %{
      total_projects: length(all_tasks |> Enum.map(& &1.project_id) |> Enum.uniq()),
      total_attachees: length(all_tasks |> Enum.map(& &1.assignee_id) |> Enum.uniq()),
      active_tasks: Enum.count(all_tasks, &(&1.status in ["pending", "in_progress"])),
      pending_reviews: Enum.count(all_tasks, &(&1.status == "submitted")),
      completed_tasks: Enum.count(all_tasks, &(&1.status == "completed"))
    }
  end

  # Admin activities
  defp load_recent_activities_for_admin(all_tasks) do
    all_tasks
    |> Enum.filter(&(&1.status in ["submitted", "completed"]))
    # FIXED HERE
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
    |> Enum.take(10)
    |> Enum.map(&format_activity/1)
  end

  # Supervisor activities
  defp load_recent_activities(all_tasks) do
    all_tasks
    |> Enum.filter(&(&1.status in ["submitted", "completed"]))
    |> Enum.sort_by(& &1.updated_at, {:desc, NaiveDateTime})
    |> Enum.take(10)
    |> Enum.map(&format_activity/1)
  end

  defp format_activity(task) do
    %{
      task_title: task.title,
      project_name: task.project.name,
      assignee_name: task.assignee.user.username || task.assignee.user.email,
      status: task.status,
      updated_at: task.updated_at
    }
  end

  @impl true
  def handle_event("view_project_tasks", %{"id" => _id}, socket) do
    {:noreply, assign(socket, :selected_project, nil) |> assign(:project_tasks, [])}
  end

  def handle_event("close_project_view", _, socket) do
    {:noreply, assign(socket, :selected_project, nil) |> assign(:project_tasks, [])}
  end

  def handle_event("toggle_task_form", _, socket) do
    {:noreply, assign(socket, :show_task_form, !socket.assigns.show_task_form)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_project_form, false) |> assign(:show_task_form, false)}
  end

  @impl true
  def handle_info({:switch_role, new_role}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.switch_user_role(user, new_role) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        # FIXED: Reload data immediately after role switch
        socket =
          socket
          |> assign(:current_scope, updated_scope)
          |> assign(:active_role, new_role)
          |> load_data(updated_user, new_role)

        redirect_path =
          case new_role do
            "admin" -> ~p"/admin/dashboard"
            "supervisor" -> ~p"/supervisor/dashboard"
            "attachee" -> ~p"/attachee"
            "manager" -> ~p"/dashboard"
            "employee" -> ~p"/dashboard"
            _ -> ~p"/dashboard"
          end

        {:noreply,
         socket
         # |> put_flash(:info, "Switched to #{new_role} role")
         |> push_navigate(to: redirect_path)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end

  def handle_info({:project_created, _}, socket) do
    user = socket.assigns.current_user
    role = socket.assigns.active_role

    {:noreply,
     socket
     |> load_data(user, role)
     |> put_flash(:info, "Project created!")
     |> assign(:show_project_form, false)}
  end

  def handle_info({:task_created, _}, socket) do
    user = socket.assigns.current_user
    role = socket.assigns.active_role

    {:noreply,
     socket
     |> load_data(user, role)
     |> put_flash(:info, "Task created!")
     |> assign(:show_task_form, false)}
  end

  def handle_info(:refresh_activity, socket) do
    # Refresh activity data
    user = socket.assigns.current_user
    role = socket.assigns.active_role

    # Reload only the activities
    all_tasks =
      if role == "admin" do
        Eams.list_tasks(%{preloads: [:project, assignee: :user]})
      else
        Eams.list_tasks_for_supervisor(user.id)
      end

    recent_activities =
      if role == "admin" do
        load_recent_activities_for_admin(all_tasks)
      else
        load_recent_activities(all_tasks)
      end

    # Schedule next refresh
    schedule_activity_refresh()

    {:noreply, assign(socket, :recent_activities, recent_activities)}
  end

  def handle_info({:task_updated, _task}, socket) do
    # Reload activities when a task is updated
    user = socket.assigns.current_user
    role = socket.assigns.active_role

    all_tasks =
      if role == "admin" do
        Eams.list_tasks(%{preloads: [:project, assignee: :user]})
      else
        Eams.list_tasks_for_supervisor(user.id)
      end

    recent_activities =
      if role == "admin" do
        load_recent_activities_for_admin(all_tasks)
      else
        load_recent_activities(all_tasks)
      end

    {:noreply, assign(socket, :recent_activities, recent_activities)}
  end

  # Schedule activity refresh every 30 seconds
  defp schedule_activity_refresh do
    Process.send_after(self(), :refresh_activity, 30_000)
  end

  # ─── HELPERS ───
  defp is_overdue?(project),
    do: project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("in_progress"), do: "bg-blue-100 text-blue-800"
  defp status_color("completed"), do: "bg-green-100 text-green-800"
  defp status_color("submitted"), do: "bg-purple-100 text-purple-800"
  defp status_color("rejected"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_date(nil), do: "Not set"
  defp format_date(date), do: Calendar.strftime(date, "%b %d, %Y")

  defp status_indicator("pending"), do: "bg-yellow-500"
  defp status_indicator("in_progress"), do: "bg-blue-500"
  defp status_indicator("completed"), do: "bg-green-500"
  defp status_indicator("submitted"), do: "bg-purple-500"
  defp status_indicator("rejected"), do: "bg-red-500"
  defp status_indicator(_), do: "bg-gray-400"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
