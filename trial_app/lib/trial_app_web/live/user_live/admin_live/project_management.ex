defmodule TrialAppWeb.AdminLive.ProjectManagement do
  use TrialAppWeb, :live_view
  require Logger

  alias TrialApp.{Eams, Orgs, Accounts}

  def mount(_params, _session, socket) do
    projects = load_projects_with_stats()

    {:ok,
     socket
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})
     |> assign(:projects, projects)
     |> assign(:show_form, false)
     |> assign(:editing_project, nil)
     |> assign(:search_query, "")
     |> assign(:orgs, Orgs.list_all_organizations())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:supervisors, Accounts.list_users_by_role("admin") ++ Accounts.list_users_by_role("manager"))
     |> assign(:form_data, empty_form())
     |> assign(:errors, %{})
     # Detail view state
     |> assign(:show_detail_view, false)
     |> assign(:selected_project, nil)
     |> assign(:project_attachees, [])
     |> assign(:project_tasks, [])
     |> assign(:active_tab, "attachees") # "attachees" | "tasks"
     # Task creation modal
     |> assign(:show_task_modal, false)
     |> assign(:task_form, %{"title" => "", "description" => "", "assignee_id" => "", "due_on" => "", "status" => "pending"})
     |> assign(:task_errors, %{})
     # Attachee modal
     |> assign(:show_attachee_modal, false)
     |> assign(:selected_attachee, nil)
     |> assign(:attachee_tasks, [])
     |> assign(:attachee_evaluations, [])
     |> assign(:attachee_stats, %{})
     |> assign(:attachee_eval_summary, %{})
     |> assign(:attachee_active_tab, "overview")
     |> assign(:show_attachee_eval_modal, false)
     |> assign(:attachee_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:attachee_eval_errors, %{})
     |> assign(:viewing_evaluation, nil)
    }
  end

  # Form Events
  def handle_event("new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_project, nil)
     |> assign(:form_data, empty_form())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:errors, %{})
    }
  end

  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:show_detail_view, false)
     |> assign(:show_task_modal, false)
     |> assign(:show_attachee_modal, false)
     |> assign(:show_attachee_eval_modal, false)
     |> assign(:editing_project, nil)
     |> assign(:selected_project, nil)
     |> assign(:selected_attachee, nil)
     |> assign(:form_data, empty_form())
     |> assign(:departments, [])
     |> assign(:programs, [])
     |> assign(:errors, %{})
     |> assign(:task_errors, %{})
     |> assign(:attachee_eval_errors, %{})
     |> assign(:task_form, %{"title" => "", "description" => "", "assignee_id" => "", "due_on" => "", "status" => "pending"})}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  # Detail View Navigation
  def handle_event("view_project_detail", %{"id" => id}, socket) do
    project_id = parse_int(id)
    project = Eams.get_project!(project_id)
              |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor, tasks: [assignee: [:user]]])

    attachees = Eams.list_attachees_by_project(project_id)
                |> TrialApp.Repo.preload(:user)

    project_with_stats = Map.put(project, :stats, Eams.get_project_stats(project_id))

    {:noreply,
     socket
     |> assign(:show_detail_view, true)
     |> assign(:selected_project, project_with_stats)
     |> assign(:project_attachees, attachees)
     |> assign(:project_tasks, project.tasks)
     |> assign(:active_tab, "attachees")}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in ["attachees", "tasks"] do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("back_to_projects", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_detail_view, false)
     |> assign(:selected_project, nil)}
  end

  def handle_event("open_task_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_task_modal, true)
     |> assign(:task_form, %{"title" => "", "description" => "", "assignee_id" => "", "due_on" => "", "status" => "pending"})
     |> assign(:task_errors, %{})}
  end

  def handle_event("close_task_modal", _params, socket) do
    {:noreply, assign(socket, :show_task_modal, false) |> assign(:task_errors, %{})}
  end

  def handle_event("create_task", %{"task" => params}, socket) do
    project = socket.assigns.selected_project

    attrs = %{
      title: params["title"],
      description: params["description"],
      assignee_id: parse_int(params["assignee_id"]),
      project_id: project.id,
      due_on: parse_date(params["due_on"]),
      status: params["status"] || "pending"
    }

    case Eams.create_task(attrs) do
      {:ok, _task} ->
        refreshed_project = Eams.get_project!(project.id)
                            |> TrialApp.Repo.preload([:tasks, assignee: [:user]], force: true)

        refreshed_attachees = Eams.list_attachees_by_project(project.id)
                              |> TrialApp.Repo.preload(:user)

        {:noreply,
         socket
         |> assign(:project_tasks, refreshed_project.tasks)
         |> assign(:project_attachees, refreshed_attachees)
         |> assign(:show_task_modal, false)
         |> put_flash(:info, "Task created successfully")}

      {:error, changeset} ->
        errors = changeset.errors |> Enum.into(%{})
        {:noreply, assign(socket, :task_errors, errors)}
    end
  end

  def handle_event("view_attachee_detail", %{"id" => id}, socket) do
    attachee_id = parse_int(id)
    attachee = Eams.get_attachee_with_details(attachee_id)
    tasks = Eams.list_tasks_by_attachee(attachee_id)
    evaluations = Eams.list_evaluations_by_attachee(attachee_id)
    stats = Eams.get_attachee_stats(attachee_id)
    eval_summary = Eams.get_evaluation_summary(attachee_id)

    {:noreply,
     socket
     |> assign(:show_attachee_modal, true)
     |> assign(:selected_attachee, attachee)
     |> assign(:attachee_tasks, tasks)
     |> assign(:attachee_evaluations, evaluations)
     |> assign(:attachee_stats, stats)
     |> assign(:attachee_eval_summary, eval_summary)
     |> assign(:attachee_active_tab, "overview")
     |> assign(:show_attachee_eval_modal, false)
     |> assign(:attachee_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:attachee_eval_errors, %{})
     |> assign(:viewing_evaluation, nil)}
  end

  def handle_event("close_attachee_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_attachee_modal, false)
     |> assign(:selected_attachee, nil)
     |> assign(:attachee_tasks, [])
     |> assign(:attachee_evaluations, [])
     |> assign(:attachee_stats, %{})
     |> assign(:attachee_eval_summary, %{})}
  end

  def handle_event("switch_attachee_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :attachee_active_tab, tab)}
  end

  def handle_event("open_attachee_eval_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_attachee_eval_modal, true)
     |> assign(:attachee_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:attachee_eval_errors, %{})}
  end

  def handle_event("close_attachee_eval_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_attachee_eval_modal, false)
     |> assign(:attachee_eval_form, %{"score" => "", "comments" => ""})
     |> assign(:attachee_eval_errors, %{})}
  end

  def handle_event("update_attachee_eval_form", %{"eval" => params}, socket) do
    {:noreply, assign(socket, :attachee_eval_form, params)}
  end

  def handle_event("submit_attachee_evaluation", %{"eval" => params}, socket) do
    attrs = %{
      score: parse_int(params["score"]),
      comments: params["comments"],
      attachee_id: socket.assigns.selected_attachee.id,
      evaluator_id: socket.assigns.current_scope.id
    }

    case Eams.create_evaluation(attrs, socket.assigns.current_scope) do
      {:ok, _evaluation} ->
        evaluations = Eams.list_evaluations_by_attachee(socket.assigns.selected_attachee.id)
        stats = Eams.get_attachee_stats(socket.assigns.selected_attachee.id)
        eval_summary = Eams.get_evaluation_summary(socket.assigns.selected_attachee.id)

        {:noreply,
         socket
         |> assign(:attachee_evaluations, evaluations)
         |> assign(:attachee_stats, stats)
         |> assign(:attachee_eval_summary, eval_summary)
         |> assign(:show_attachee_eval_modal, false)
         |> assign(:attachee_eval_form, %{"score" => "", "comments" => ""})
         |> assign(:attachee_eval_errors, %{})
         |> put_flash(:info, "Evaluation submitted successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> {field, msg} end)
          |> Enum.into(%{})

        {:noreply, assign(socket, :attachee_eval_errors, errors)}
    end
  end

  def handle_event("view_evaluation", %{"id" => id}, socket) do
    evaluation = Eams.get_evaluation!(parse_int(id))
                  |> TrialApp.Repo.preload([:evaluator])
    {:noreply, assign(socket, :viewing_evaluation, evaluation)}
  end

  def handle_event("close_eval_view", _params, socket) do
    {:noreply, assign(socket, :viewing_evaluation, nil)}
  end

  def handle_event("update", %{"project" => params}, socket) do
    org_id = Map.get(params, "organization_id")
    dept_id = Map.get(params, "department_id")

    org_int = safe_int(org_id)
    dept_int = safe_int(dept_id)

    departments = if is_integer(org_int), do: Orgs.list_departments_by_org(org_int), else: []
    programs = if is_integer(dept_int), do: Eams.list_programs_by_department(dept_int), else: []

    errors = socket.assigns.errors
    |> Map.delete(:starts_on)
    |> Map.delete(:ends_on)
    |> Map.delete(:date_range)

    {:noreply,
     socket
     |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
     |> assign(:departments, departments)
     |> assign(:programs, programs)
     |> assign(:errors, errors)}
  end

  def handle_event("save", %{"project" => params}, socket) do
    Logger.info("Attempting to save project with params: #{inspect(params)}")

    case validate_dates(params) do
      {:ok, _} ->
        attrs = %{
          name: params["name"],
          description: params["description"],
          code: params["code"],
          starts_on: parse_date(params["starts_on"]),
          ends_on: parse_date(params["ends_on"]),
          organization_id: parse_int(params["organization_id"]),
          department_id: parse_int(params["department_id"]),
          program_id: parse_int(params["program_id"]),
          supervisor_id: parse_int(params["supervisor_id"]),
          is_active: true
        }

        result = if socket.assigns.editing_project do
          Eams.update_project(socket.assigns.editing_project, attrs)
        else
          Eams.create_project(attrs)
        end

        case result do
          {:ok, _project} ->
            {:noreply,
             socket
             |> assign(:show_form, false)
             |> assign(:editing_project, nil)
             |> assign(:form_data, empty_form())
             |> assign(:departments, [])
             |> assign(:programs, [])
             |> assign(:projects, load_projects_with_stats())
             |> assign(:errors, %{})
             |> put_flash(:info, "Project #{if socket.assigns.editing_project, do: "updated", else: "created"} successfully")}

          {:error, %Ecto.Changeset{} = changeset} ->
            errors = changeset.errors |> Enum.into(%{})
            {:noreply, assign(socket, errors: errors)}
        end

      {:error, message} ->
        {:noreply, assign(socket, errors: %{date_range: message})}
    end
  end

  def handle_event("edit_project", %{"id" => id}, socket) do
    project = Eams.get_project!(parse_int(id))
              |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor])

    org_id = project.organization_id
    dept_id = project.department_id

    departments = if org_id, do: Orgs.list_departments_by_org(org_id), else: []
    programs = if dept_id, do: Eams.list_programs_by_department(dept_id), else: []

    form_data = %{
      "name" => project.name || "",
      "description" => project.description || "",
      "code" => project.code || "",
      "starts_on" => if(project.starts_on, do: Date.to_string(project.starts_on), else: ""),
      "ends_on" => if(project.ends_on, do: Date.to_string(project.ends_on), else: ""),
      "organization_id" => if(org_id, do: to_string(org_id), else: ""),
      "department_id" => if(dept_id, do: to_string(dept_id), else: ""),
      "program_id" => if(project.program_id, do: to_string(project.program_id), else: ""),
      "supervisor_id" => if(project.supervisor_id, do: to_string(project.supervisor_id), else: "")
    }

    {:noreply,
     socket
     |> assign(:editing_project, project)
     |> assign(:show_form, true)
     |> assign(:form_data, form_data)
     |> assign(:departments, departments)
     |> assign(:programs, programs)
     |> assign(:errors, %{})}
  end

  def handle_event("delete_project", %{"id" => id}, socket) do
    project = Eams.get_project!(parse_int(id))

    case Eams.delete_project(project) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> assign(:projects, load_projects_with_stats())
         |> put_flash(:info, "Project deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to delete project")}
    end
  end

  # Helpers
  defp load_projects_with_stats do
    try do
      Eams.list_projects()
      |> TrialApp.Repo.preload([:organization, :department, :program, :supervisor])
      |> Enum.map(fn project ->
        stats = Eams.get_project_stats(project.id)
        Map.put(project, :stats, stats)
      end)
    rescue
      e ->
        Logger.error("Error loading projects with stats: #{inspect(e)}")
        []
    end
  end

  defp empty_form do
    %{
      "name" => "",
      "description" => "",
      "organization_id" => "",
      "department_id" => "",
      "program_id" => "",
      "supervisor_id" => "",
      "code" => "",
      "starts_on" => "",
      "ends_on" => ""
    }
  end

  defp filtered_projects(projects, ""), do: projects
  defp filtered_projects(projects, query) do
    query = String.downcase(query)
    Enum.filter(projects, fn project ->
      String.contains?(String.downcase(project.name || ""), query) ||
      (project.code && String.contains?(String.downcase(project.code), query)) ||
      (project.description && String.contains?(String.downcase(project.description), query))
    end)
  end

  defp project_status(project) do
    cond do
      !project.is_active -> :inactive
      project.ends_on && Date.compare(project.ends_on, Date.utc_today()) == :lt -> :completed
      project.starts_on && Date.compare(project.starts_on, Date.utc_today()) == :gt -> :upcoming
      true -> :active
    end
  end

  defp attachee_name(attachee) do
    if Ecto.assoc_loaded?(attachee.user) && attachee.user do
      attachee.user.username || attachee.user.email
    else
      "Attachee ##{attachee.id}"
    end
  end

  defp task_status_color(status) do
    case status do
      "completed" -> "bg-green-100 text-green-800"
      "in_progress" -> "bg-blue-100 text-blue-800"
      "submitted" -> "bg-purple-100 text-purple-800"
      "rejected" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp score_bg_color(score) do
    cond do
      score >= 81 -> "bg-green-600 text-white"
      score >= 61 -> "bg-blue-600 text-white"
      score >= 41 -> "bg-amber-600 text-white"
      true -> "bg-red-600 text-white"
    end
  end

  defp score_color(score) when score >= 81, do: "text-green-600"
  defp score_color(score) when score >= 61, do: "text-blue-600"
  defp score_color(score) when score >= 41, do: "text-amber-600"
  defp score_color(_), do: "text-red-600"

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

  defp validate_dates(params) do
    starts_on = parse_date(params["starts_on"])
    ends_on = parse_date(params["ends_on"])

    cond do
      is_nil(starts_on) and is_nil(ends_on) ->
        {:ok, nil}
      is_nil(starts_on) and not is_nil(ends_on) ->
        {:error, "Start date is required when end date is provided"}
      not is_nil(starts_on) and not is_nil(ends_on) and Date.compare(ends_on, starts_on) == :lt ->
        {:error, "End date must be after start date"}
      true ->
        {:ok, nil}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(nil), do: nil
  defp safe_int(""), do: nil
  defp safe_int(val) when is_integer(val), do: val
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    date_string = String.trim(date_string)

    cond do
      String.match?(date_string, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        parse_iso_date(date_string)
      true ->
        nil
    end
  end
  defp parse_date(_), do: nil

  defp parse_iso_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    with {year, _} <- Integer.parse(y),
         {month, _} <- Integer.parse(m),
         {day, _} <- Integer.parse(d),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _ -> nil
    end
  end
  defp parse_iso_date(_), do: nil
end
