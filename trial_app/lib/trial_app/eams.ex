defmodule TrialApp.Eams do
  @moduledoc """
  EAMS context: Programs, Projects, Attachees, Tasks, Teams, Supervisors.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Eams.{
    Program,
    Project,
    Task,
    Attachee,
    AttacheeProgram,
    ProjectAttachee,
    Team,
    TeamMember,
    Evaluation
  }

  alias TrialApp.{Accounts, Orgs}

  # PROGRAMS
  def list_programs(opts \\ %{}) do
    Program
    |> preload(^Map.get(opts, :preloads, [:department, :organization]))
    |> Repo.all()
  end

  def list_programs_by_department(department_id, opts \\ %{}) do
    Program
    |> where([p], p.department_id == ^department_id)
    |> preload(^Map.get(opts, :preloads, [:department, :organization]))
    |> Repo.all()
  end

  def get_program!(id, opts \\ %{}) do
    Program
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:department, :organization]))
  end

  @doc """
  Gets a program with its projects preloaded.
  """
  def get_program_with_projects(id) do
    Program
    |> Repo.get!(id)
    |> Repo.preload([
      :organization,
      :department,
      projects: [:supervisor, :department, :organization]
    ])
  end

  @doc """
  Gets statistics for a program (projects and attachees counts).
  """
  def get_program_stats(program_id) do
    # Get all projects for this program
    projects = list_projects_by_program(program_id, %{preloads: []})

    # Ensure projects is a list
    projects = if is_list(projects), do: projects, else: []

    total_projects = length(projects)

    active_projects =
      Enum.count(projects, fn p ->
        Map.get(p, :is_active, false) &&
          (!Map.get(p, :ends_on) || Date.compare(p.ends_on, Date.utc_today()) != :lt)
      end)

    # Get all unique attachees across all projects via project_attachees OR tasks
    project_ids = Enum.map(projects, & &1.id)

    {total_attachees, active_attachees} =
      if Enum.empty?(project_ids) do
        {0, 0}
      else
        try do
          attachees =
            from(a in Attachee,
              left_join: pa in ProjectAttachee,
              on: pa.attachee_id == a.id and pa.project_id in ^project_ids,
              left_join: t in Task,
              on: t.assignee_id == a.id and t.project_id in ^project_ids,
              where: not is_nil(pa.id) or not is_nil(t.id),
              distinct: true,
              select: a
            )
            |> Repo.all()

          total = length(attachees)
          active = Enum.count(attachees, fn a -> a.status == "active" end)
          {total, active}
        rescue
          _ -> {0, 0}
        end
      end

    %{
      total_projects: total_projects,
      active_projects: active_projects,
      total_attachees: total_attachees,
      active_attachees: active_attachees
    }
  end

  def create_program(attrs) do
    %Program{}
    |> Program.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_program(%Program{} = program, attrs) do
    program
    |> Program.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_program(%Program{} = program), do: Repo.delete(program)

  # PROJECTS
  def list_projects(opts \\ %{}) do
    Project
    |> preload(^Map.get(opts, :preloads, [:program, :department, :organization]))
    |> Repo.all()
  end

  # Declare function head with defaults
  def list_projects_by_program(program_id, opts \\ %{})

  # Define implementation without defaults
  def list_projects_by_program(program_id, opts) do
    try do
      Project
      |> where([p], p.program_id == ^program_id)
      |> preload(
        ^Map.get(opts, :preloads, [:program, :department, :organization, :supervisor, :attachees])
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  def list_projects_by_supervisor(supervisor_id, opts \\ %{}) do
    Project
    |> where([p], p.supervisor_id == ^supervisor_id)
    |> preload(^Map.get(opts, :preloads, [:program, :department, :organization]))
    |> Repo.all()
  end

  def list_projects_by_programs(program_ids) when is_list(program_ids) and program_ids != [] do
    from(p in Project,
      where: p.program_id in ^program_ids,
      where: p.is_active == true,
      preload: [:program, :department, :organization]
    )
    |> Repo.all()
  end

  def list_projects_by_programs(_), do: []

  @doc """
  Lists all projects for a specific attachee.
  Gets projects via both project_attachees join table AND tasks.
  """
  def list_projects_by_attachee(attachee_id) do
    from(p in Project,
      left_join: pa in ProjectAttachee,
      on: pa.project_id == p.id and pa.attachee_id == ^attachee_id,
      left_join: t in Task,
      on: t.project_id == p.id and t.assignee_id == ^attachee_id,
      where: not is_nil(pa.id) or not is_nil(t.id),
      distinct: true,
      preload: [:program, :department, :organization, :supervisor],
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  def get_project!(id, opts \\ %{}) do
    Project
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:program, :department, :organization]))
  end

  @doc """
  Gets a project with detailed preloads for the show page.
  """
  def get_project_with_details(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload([
      :program,
      :supervisor,
      :department,
      :organization
    ])
  end

  @doc """
  Gets statistics for a project (attachees and tasks).
  UPDATED: Now includes attachees from both project_attachees AND tasks.
  """
  def get_project_stats(project_id) do
    # Get all attachees via project_attachees OR tasks
    attachees =
      from(a in Attachee,
        left_join: pa in ProjectAttachee,
        on: pa.attachee_id == a.id and pa.project_id == ^project_id,
        left_join: t in Task,
        on: t.assignee_id == a.id and t.project_id == ^project_id,
        where: not is_nil(pa.id) or not is_nil(t.id),
        distinct: true,
        select: a
      )
      |> Repo.all()

    total_attachees = length(attachees)
    active_attachees = Enum.count(attachees, fn a -> a.status == "active" end)

    # Get tasks for this project
    tasks = list_tasks_by_project(project_id)

    total_tasks = length(tasks)
    completed_tasks = Enum.count(tasks, fn t -> t.status == "completed" end)

    completion_rate =
      if total_tasks > 0 do
        Float.round(completed_tasks / total_tasks * 100, 1)
      else
        0.0
      end

    %{
      total_attachees: total_attachees,
      active_attachees: active_attachees,
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      completion_rate: completion_rate
    }
  end

  @doc """
  Lists all attachees assigned to a project via project_attachees OR tasks.
  UPDATED: Now includes attachees who have tasks in the project even if not explicitly added.
  """
  def list_attachees_by_project(project_id) do
    from(a in Attachee,
      left_join: pa in ProjectAttachee,
      on: pa.attachee_id == a.id and pa.project_id == ^project_id,
      left_join: t in Task,
      on: t.assignee_id == a.id and t.project_id == ^project_id,
      where: not is_nil(pa.id) or not is_nil(t.id),
      distinct: true,
      preload: [:user, :department, :organization],
      order_by: [asc: a.id]
    )
    |> Repo.all()
  end

  @doc """
  Adds an attachee to a project using the project_attachees join table.
  """
  def add_attachee_to_project(project_id, attachee_id, attrs \\ %{}) do
    %ProjectAttachee{}
    |> ProjectAttachee.changeset(%{
      project_id: project_id,
      attachee_id: attachee_id,
      role: Map.get(attrs, :role, "Intern"),
      joined_at: Map.get(attrs, :joined_at, Date.utc_today())
    })
    |> Repo.insert()
  end

  @doc """
  Removes an attachee from a project by deleting the project_attachees record.
  """
  def remove_attachee_from_project(project_id, attachee_id) do
    from(pa in ProjectAttachee,
      where: pa.project_id == ^project_id and pa.attachee_id == ^attachee_id
    )
    |> Repo.delete_all()

    {:ok, :removed}
  end

  def create_project(attrs) do
    %Project{}
    |> Project.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.update_changeset(attrs)
    |> Repo.update()
  end

  def approve_project(%Project{} = project) do
    project
    |> Project.changeset(%{status: "active", is_active: true})
    |> Repo.update()
  end

  def reject_project(%Project{} = project) do
    project
    |> Project.changeset(%{status: "rejected", is_active: false})
    |> Repo.update()
  end

  def list_pending_projects do
    Project
    |> where([p], p.status == "pending")
    |> preload([:supervisor, :department, :organization, :program])
    |> Repo.all()
  end

  def delete_project(%Project{} = project), do: Repo.delete(project)

  def count_projects do
    Repo.aggregate(Project, :count, :id)
  end

  # ATTACHEE
  def list_attachees(opts \\ %{}) do
    Attachee
    |> preload(^Map.get(opts, :preloads, [:user, :department, :organization]))
    |> Repo.all()
  end

  def list_attachees_by_department(department_id, opts \\ %{}) do
    Attachee
    |> where([a], a.department_id == ^department_id)
    |> preload(^Map.get(opts, :preloads, [:user, :department, :organization]))
    |> Repo.all()
  end

  def list_attachees_in_program(program_id) do
    from(a in Attachee,
      join: ap in AttacheeProgram,
      on: ap.attachee_id == a.id,
      where: ap.program_id == ^program_id and a.status == "active",
      preload: [:user, :department, :organization],
      order_by: [asc: a.id]
    )
    |> Repo.all()
  end

  @doc """
  Lists all attachees assigned to a program with optional preloads.
  """
  def list_attachees_by_program(program_id, opts \\ %{}) do
    from(a in Attachee,
      join: ap in AttacheeProgram,
      on: ap.attachee_id == a.id,
      where: ap.program_id == ^program_id and a.status == "active",
      preload: ^Map.get(opts, :preloads, [:user, :department, :organization]),
      order_by: [asc: a.id]
    )
    |> Repo.all()
  end

  @doc """
  Lists all attachees assigned to tasks in a specific project.
  """
  def list_attachees_in_project(project_id) do
    from(a in Attachee,
      join: pa in ProjectAttachee,
      on: pa.attachee_id == a.id,
      where: pa.project_id == ^project_id,
      preload: [:user, :department, :organization]
    )
    |> Repo.all()
  end

  def enroll_attachee_in_program(attachee_id, program_id) do
    %AttacheeProgram{}
    |> AttacheeProgram.changeset(%{attachee_id: attachee_id, program_id: program_id})
    |> Repo.insert()
  end

  def get_attachee_by_user(user_id) do
    Attachee
    |> where([a], a.user_id == ^user_id)
    |> preload([:user, :department, :organization])
    |> Repo.one()
  end

  def list_programs_for_attachee(attachee_id) do
    from(p in Program,
      join: ap in AttacheeProgram,
      on: ap.program_id == p.id,
      where: ap.attachee_id == ^attachee_id,
      preload: [:department, :organization]
    )
    |> Repo.all()
  end

  def list_tasks_for_attachee(attachee_id) do
    Task
    |> where([t], t.assignee_id == ^attachee_id)
    |> preload([:project, assignee: :user])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  def list_projects_for_attachee(attachee_id) do
    from(pr in Project,
      join: t in Task,
      on: t.project_id == pr.id,
      where: t.assignee_id == ^attachee_id,
      where: pr.status == "active",
      distinct: true
    )
    |> preload([:program, :department, :organization])
    |> Repo.all()
  end

  def get_attachee!(id, opts \\ %{}) do
    Attachee
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:user, :department, :organization]))
  end

  @doc """
  Gets an attachee with all necessary preloads for the show page.
  """
  def get_attachee_with_details(id) do
    Attachee
    |> Repo.get!(id)
    |> Repo.preload([:user, :department, :organization])
  end

  @doc """
  Lists all tasks for a specific attachee.
  """
  def list_tasks_by_attachee(attachee_id) do
    Task
    |> where([t], t.assignee_id == ^attachee_id)
    |> preload([:project, task_evaluations: [:evaluator]])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all evaluations for a specific attachee (general evaluations only, not task-specific).
  """
  def list_evaluations_by_attachee(attachee_id) do
    Evaluation
    |> where([e], e.attachee_id == ^attachee_id and is_nil(e.task_id))
    |> preload([:evaluator])
    |> order_by([e], desc: e.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets comprehensive stats for an attachee.
  """
  def get_attachee_stats(attachee_id) do
    # Get projects via tasks
    projects =
      from(p in Project,
        join: t in Task,
        on: t.project_id == p.id,
        where: t.assignee_id == ^attachee_id,
        distinct: p.id
      )
      |> Repo.all()

    # Get tasks
    tasks = list_tasks_by_attachee(attachee_id)
    total_tasks = length(tasks)
    completed_tasks = Enum.count(tasks, fn t -> t.status == "completed" end)

    completion_rate =
      if total_tasks > 0 do
        Float.round(completed_tasks / total_tasks * 100, 1)
      else
        0.0
      end

    %{
      total_projects: length(projects),
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      completion_rate: completion_rate
    }
  end

  @doc """
  Gets evaluation summary with averages and trends (general evaluations only).
  """
  def get_evaluation_summary(attachee_id) do
    evaluations = list_evaluations_by_attachee(attachee_id)

    if Enum.empty?(evaluations) do
      %{
        total_evaluations: 0,
        average_score: 0.0,
        highest_score: 0,
        latest_score: 0,
        trend: "stable"
      }
    else
      scores = Enum.map(evaluations, & &1.score)
      total = length(scores)
      average = Float.round(Enum.sum(scores) / total, 1)
      highest = Enum.max(scores)
      latest = hd(scores)

      # Calculate trend (comparing latest 3 vs previous 3)
      trend = calculate_trend(scores)

      %{
        total_evaluations: total,
        average_score: average,
        highest_score: highest,
        latest_score: latest,
        trend: trend
      }
    end
  end

  defp calculate_trend(scores) when length(scores) < 4, do: "stable"

  defp calculate_trend(scores) do
    recent_sum = scores |> Enum.take(3) |> Enum.sum()
    recent = recent_sum / 3

    previous_sum = scores |> Enum.slice(3, 3) |> Enum.sum()
    previous = previous_sum / 3

    cond do
      recent > previous + 5 -> "improving"
      recent < previous - 5 -> "declining"
      true -> "stable"
    end
  end

  @doc """
  Creates an attachee and sends welcome email with credentials.
  Returns {:ok, attachee, :email_sent} or {:ok, attachee, :email_failed}
  """
  def create_attachee_with_email(attrs, plain_password) do
    case create_attachee(attrs) do
      {:ok, attachee} ->
        # Preload user to send email
        attachee = Repo.preload(attachee, :user)

        # Try to send email
        case Accounts.deliver_attachee_welcome_email(attachee.user, plain_password) do
          {:ok, :email_sent} ->
            {:ok, attachee, :email_sent}

          {:error, _reason} ->
            {:ok, attachee, :email_failed}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_attachee(attrs) do
    %Attachee{}
    |> Attachee.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_attachee(%Attachee{} = attachee, attrs) do
    attachee
    |> Attachee.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_attachee(%Attachee{} = attachee), do: Repo.delete(attachee)

  def count_attachees do
    Repo.aggregate(Attachee, :count, :id)
  end

  # TASKS
  def list_tasks(opts \\ %{}) do
    Task
    |> preload(^Map.get(opts, :preloads, [:project, :assignee]))
    |> Repo.all()
  end

  def get_task!(id, opts \\ %{}) do
    # Convert keyword list to map if needed
    opts_map = if is_list(opts), do: Enum.into(opts, %{}), else: opts

    Task
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts_map, :preloads, [:project, :assignee, [assignee: :user]]))
  end

  @doc """
  Creates a task and automatically adds the assignee to the project if not already there.
  """
  def create_task(attrs) do
    result =
      %Task{}
      |> Task.create_changeset(attrs)
      |> Repo.insert()

    # Automatically add attachee to project if not already there
    case result do
      {:ok, task} ->
        if task.assignee_id && task.project_id do
          # Check if attachee is already in project
          existing =
            from(pa in ProjectAttachee,
              where: pa.project_id == ^task.project_id and pa.attachee_id == ^task.assignee_id
            )
            |> Repo.one()

          # Add to project if not already there
          if is_nil(existing) do
            add_attachee_to_project(task.project_id, task.assignee_id, %{
              role: "Intern",
              joined_at: Date.utc_today()
            })
          end
        end

        # Broadcast task creation for real-time dashboard updates
        Phoenix.PubSub.broadcast(
          TrialApp.PubSub,
          "tasks",
          {:task_updated, task}
        )

        {:ok, task}

      error ->
        error
    end
  end

  def update_task(%Task{} = task, attrs) do
    result =
      task
      |> Task.update_changeset(attrs)
      |> Repo.update()

    # Broadcast task update for real-time dashboard updates
    case result do
      {:ok, updated_task} ->
        Phoenix.PubSub.broadcast(
          TrialApp.PubSub,
          "tasks",
          {:task_updated, updated_task}
        )

        {:ok, updated_task}

      error ->
        error
    end
  end

  def delete_task(%Task{} = task), do: Repo.delete(task)

  def list_tasks_by_project(project_id) do
    Task
    |> where([t], t.project_id == ^project_id)
    |> preload([:project, assignee: [:user]])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  # TASK SUBMISSION & REJECTION
  @doc """
  Submit a task with comment, links, and files.
  """
  def submit_attachee_task(task_id, attrs) when is_map(attrs) do
    task = get_task!(task_id, %{preloads: [:project, :assignee]})

    # Extract submission data
    comment = Map.get(attrs, :comment) || Map.get(attrs, "comment") || ""
    links = Map.get(attrs, :links) || Map.get(attrs, "links") || []
    files = Map.get(attrs, :files) || Map.get(attrs, "files") || []

    # Prepare update attributes
    update_attrs = %{
      status: "submitted",
      submitted_at: DateTime.utc_now(),
      reject_reason: nil,
      submission_comment: comment,
      submission_links: links,
      submission_files: files
    }

    task
    |> Task.changeset(update_attrs)
    |> Repo.update()
  end

  @doc """
  Reject a task with a reason.
  """
  def reject_attachee_task(task_id, reason) do
    task = get_task!(task_id, %{preloads: [:project, :assignee]})

    task
    |> Task.changeset(%{
      status: "rejected",
      reject_reason: reason
    })
    |> Repo.update()
  end

  @doc """
  Approve/complete a task.
  """
  def approve_attachee_task(task_id) do
    task = get_task!(task_id, %{preloads: [:project, :assignee]})

    task
    |> Task.changeset(%{
      status: "completed"
    })
    |> Repo.update()
  end

  # SUPERVISOR TASKS MANAGEMENT
  def list_tasks_for_supervisor(supervisor_id) do
    # Get all projects where supervisor is involved
    projects = list_projects_for_supervisor(supervisor_id)
    project_ids = Enum.map(projects, & &1.id)

    if Enum.empty?(project_ids) do
      []
    else
      Task
      |> where([t], t.project_id in ^project_ids)
      |> preload([:project, assignee: :user])
      |> order_by([t], desc: t.inserted_at)
      |> Repo.all()
    end
  end

  @doc """
  Lists all tasks for a specific project.
  """
  def list_tasks_for_project(project_id) do
    Task
    |> where([t], t.project_id == ^project_id)
    |> preload([:project, assignee: :user])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all attachees for a supervisor based on their assigned projects.
  Includes attachees assigned to the projects OR having tasks in the projects.
  """
  def list_attachees_for_supervisor(supervisor_id) do
    # Get all projects for this supervisor
    projects = list_projects_for_supervisor(supervisor_id)
    project_ids = Enum.map(projects, & &1.id)

    if Enum.empty?(project_ids) do
      []
    else
      from(a in Attachee,
        left_join: pa in ProjectAttachee,
        on: pa.attachee_id == a.id and pa.project_id in ^project_ids,
        left_join: t in Task,
        on: t.assignee_id == a.id and t.project_id in ^project_ids,
        where: not is_nil(pa.id) or not is_nil(t.id),
        distinct: true,
        preload: [:user, :department, :organization]
      )
      |> Repo.all()
    end
  end

  # SUPERVISOR DASHBOARD HELPERS
  defp get_supervisor_department(supervisor_id) do
    user = Accounts.get_user!(supervisor_id)
    Orgs.get_department_for_user(user.id)
  end

  def list_projects_for_supervisor(supervisor_id) do
    Project
    |> where([p], p.supervisor_id == ^supervisor_id)
    |> preload([:program, :department, :organization])
    |> Repo.all()
  end

  def count_projects_for_supervisor(supervisor_id) do
    supervisor_id
    |> list_projects_for_supervisor()
    |> length()
  end

  def count_attachees_under_supervisor(supervisor_id) do
    case get_supervisor_department(supervisor_id) do
      nil ->
        0

      dept ->
        from(a in Attachee,
          where: a.department_id == ^dept.id,
          where: a.status == "active",
          select: count(a.id)
        )
        |> Repo.one() || 0
    end
  end

  def count_active_tasks_for_supervisor(supervisor_id) do
    from(task in Task,
      join: a in Attachee,
      on: task.assignee_id == a.id,
      join: tm in TeamMember,
      on: tm.user_id == a.user_id,
      join: t in Team,
      on: t.id == tm.team_id,
      where: t.supervisor_id == ^supervisor_id,
      where: task.status in ["pending", "in_progress"],
      select: count(task.id)
    )
    |> Repo.one() || 0
  end

  def count_pending_task_reviews(supervisor_id) do
    from(task in Task,
      join: a in Attachee,
      on: task.assignee_id == a.id,
      join: tm in TeamMember,
      on: tm.user_id == a.user_id,
      where:
        tm.team_id in subquery(
          from t in Team,
            where: t.department_id == ^get_supervisor_department(supervisor_id).id,
            select: t.id
        ),
      where: task.status != "completed",
      select: count(task.id)
    )
    |> Repo.one() || 0
  end

  # DASHBOARD AGGREGATIONS
  def count_attachees_by_department do
    from(a in Attachee,
      join: d in Orgs.Department,
      on: a.department_id == d.id,
      group_by: d.name,
      select: {d.name, count(a.id)}
    )
    |> Repo.all()
  end

  def count_projects_by_status do
    from(p in Project,
      group_by: p.status,
      select: {p.status, count(p.id)}
    )
    |> Repo.all()
  end

  def count_completed_tasks_this_week(supervisor_id) do
    beginning_of_week = Date.utc_today() |> Date.beginning_of_week()
    start_of_week = DateTime.new!(beginning_of_week, ~T[00:00:00])

    from(task in Task,
      join: a in Attachee,
      on: task.assignee_id == a.id,
      join: tm in TeamMember,
      on: tm.user_id == a.user_id,
      join: t in Team,
      on: t.id == tm.team_id,
      where: t.supervisor_id == ^supervisor_id,
      where: task.status == "completed",
      where: task.updated_at >= ^start_of_week,
      select: count(task.id)
    )
    |> Repo.one() || 0
  end

  def list_recent_activities_for_supervisor(supervisor_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    from(task in Task,
      join: a in Attachee,
      on: task.assignee_id == a.id,
      join: u in assoc(a, :user),
      join: tm in TeamMember,
      on: tm.user_id == a.user_id,
      join: t in Team,
      on: t.id == tm.team_id,
      where: t.supervisor_id == ^supervisor_id,
      where: task.status in ["submitted", "completed"],
      order_by: [desc: task.updated_at],
      limit: ^limit,
      select: %{
        attachee_name: fragment("COALESCE(?, ?)", u.username, u.email),
        description: task.title,
        time: fragment("to_char(?, 'HH12:MI AM · Mon DD')", task.updated_at),
        status: task.status
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      status = if row.status == "submitted", do: "pending", else: row.status
      %{row | status: status}
    end)
  end

  # EVALUATIONS (General Attachee Evaluations)
  def create_evaluation(attrs, user_scope) do
    %Evaluation{}
    |> Evaluation.changeset(attrs, user_scope)
    |> Repo.insert()
  end

  def list_evaluations_for_attachee(attachee_id, opts \\ %{}) do
    Evaluation
    |> where([e], e.attachee_id == ^attachee_id and is_nil(e.task_id))
    |> order_by([e], desc: e.inserted_at)
    |> preload(^Map.get(opts, :preloads, [:evaluator]))
    |> Repo.all()
  end

  def get_evaluation!(id, opts \\ %{}) do
    Evaluation
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:attachee, :evaluator]))
  end

  def update_evaluation(%Evaluation{} = evaluation, attrs, user_scope) do
    evaluation
    |> Evaluation.changeset(attrs, user_scope)
    |> Repo.update()
  end

  def delete_evaluation(%Evaluation{} = evaluation) do
    Repo.delete(evaluation)
  end

  def get_average_evaluation_score(attachee_id) do
    from(e in Evaluation,
      where: e.attachee_id == ^attachee_id and is_nil(e.task_id),
      select: avg(e.score)
    )
    |> Repo.one()
    |> case do
      nil ->
        0.0

      %Decimal{} = d ->
        d
        |> Decimal.round(1)
        |> Decimal.to_float()

      n when is_number(n) ->
        Float.round(n, 1)

      _ ->
        0.0
    end
  end

  def count_evaluations_for_attachee(attachee_id) do
    from(e in Evaluation,
      where: e.attachee_id == ^attachee_id and is_nil(e.task_id),
      select: count(e.id)
    )
    |> Repo.one() || 0
  end

  def get_latest_evaluation_for_attachee(attachee_id) do
    from(e in Evaluation,
      where: e.attachee_id == ^attachee_id and is_nil(e.task_id),
      order_by: [desc: e.inserted_at],
      limit: 1,
      preload: [:evaluator]
    )
    |> Repo.one()
  end

  def get_evaluation_categories_for_attachee(attachee_id) do
    _evaluations = list_evaluations_for_attachee(attachee_id)
    avg_score = get_average_evaluation_score(attachee_id)

    [
      %{category: "Technical Skills", score: calculate_category_score(avg_score, 1.0), max: 100},
      %{category: "Communication", score: calculate_category_score(avg_score, 0.95), max: 100},
      %{category: "Teamwork", score: calculate_category_score(avg_score, 0.9), max: 100},
      %{category: "Initiative", score: calculate_category_score(avg_score, 1.05), max: 100},
      %{category: "Professionalism", score: calculate_category_score(avg_score, 0.98), max: 100}
    ]
  end

  defp calculate_category_score(avg_score, multiplier) do
    score = avg_score * multiplier
    min(round(score), 100)
  end

  # TASK EVALUATIONS (Task-Specific Evaluations)
  @doc """
  Creates a task evaluation (evaluation with task_id).
  """
  def create_task_evaluation(attrs, user_scope) do
    %Evaluation{}
    |> Evaluation.changeset(attrs, user_scope)
    |> Repo.insert()
  end

  @doc """
  Gets a single task evaluation.
  """
  def get_task_evaluation!(id, opts \\ %{}) do
    Evaluation
    |> where([e], not is_nil(e.task_id))
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:task, :attachee, :evaluator]))
  end

  @doc """
  Lists all task evaluations for a specific task.
  """
  def list_task_evaluations_by_task(task_id, opts \\ %{}) do
    Evaluation
    |> where([e], e.task_id == ^task_id)
    |> order_by([e], desc: e.inserted_at)
    |> preload(^Map.get(opts, :preloads, [:evaluator]))
    |> Repo.all()
  end

  @doc """
  Lists all task evaluations for a specific attachee.
  """
  def list_task_evaluations_by_attachee(attachee_id, opts \\ %{}) do
    Evaluation
    |> where([e], e.attachee_id == ^attachee_id and not is_nil(e.task_id))
    |> order_by([e], desc: e.inserted_at)
    |> preload(^Map.get(opts, :preloads, [:task, :evaluator]))
    |> Repo.all()
  end

  @doc """
  Updates a task evaluation.
  """
  def update_task_evaluation(%Evaluation{} = task_evaluation, attrs, user_scope) do
    task_evaluation
    |> Evaluation.changeset(attrs, user_scope)
    |> Repo.update()
  end

  @doc """
  Deletes a task evaluation.
  """
  def delete_task_evaluation(%Evaluation{} = task_evaluation) do
    Repo.delete(task_evaluation)
  end
end
