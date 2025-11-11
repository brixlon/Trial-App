defmodule TrialApp.Eams do
  @moduledoc """
  EAMS context: Programs, Projects, Attachees, Tasks, Teams, Supervisors.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Eams.{
    Program, Project, Task, Attachee, AttacheeProgram, Team, TeamMember, Evaluation
  }
  alias TrialApp.Orgs.{Department, Organization}
  alias TrialApp.Accounts.User
  alias TrialApp.{Accounts, Orgs}

  # ──────────────────────────────────────────────────────────────────────
  # PROGRAMS
  # ──────────────────────────────────────────────────────────────────────
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

  # ──────────────────────────────────────────────────────────────────────
  # PROJECTS
  # ──────────────────────────────────────────────────────────────────────
  def list_projects(opts \\ %{}) do
    Project
    |> preload(^Map.get(opts, :preloads, [:program, :department, :organization]))
    |> Repo.all()
  end

  def list_projects_by_program(program_id, opts \\ %{}) do
    Project
    |> where([p], p.program_id == ^program_id)
    |> preload(^Map.get(opts, :preloads, [:program, :department, :organization]))
    |> Repo.all()
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

  def get_project!(id, opts \\ %{}) do
    Project
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:program, :department, :organization]))
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

  def delete_project(%Project{} = project), do: Repo.delete(project)

  # ──────────────────────────────────────────────────────────────────────
  # ATTACHEES
  # ──────────────────────────────────────────────────────────────────────
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

  # FIXED: Use AttacheeProgram join
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
  Lists all attachees assigned to tasks in a specific project.
  """
  def list_attachees_in_project(project_id) do
    from(a in Attachee,
      join: t in Task, on: t.assignee_id == a.id,
      where: t.project_id == ^project_id,
      distinct: a.id,
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

  # ──────────────────────────────────────────────────────────────────────
  # TASKS
  # ──────────────────────────────────────────────────────────────────────
  def list_tasks(opts \\ %{}) do
    Task
    |> preload(^Map.get(opts, :preloads, [:project, :assignee]))
    |> Repo.all()
  end

  # FIXED: Handle both map and keyword list opts
  def get_task!(id, opts \\ %{}) do
    # Convert keyword list to map if needed
    opts_map = if is_list(opts), do: Enum.into(opts, %{}), else: opts

    Task
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts_map, :preloads, [:project, :assignee, [assignee: :user]]))
  end

  def create_task(attrs) do
    %Task{}
    |> Task.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_task(%Task{} = task), do: Repo.delete(task)

  # ──────────────────────────────────────────────────────────────────────
  # TASK SUBMISSION & REJECTION
  # ──────────────────────────────────────────────────────────────────────

  @doc """
  Submit a task with comment, links, and files.
  Accepts attrs as a map with keys: :comment, :links, :files
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

  # ──────────────────────────────────────────────────────────────────────
  # SUPERVISOR TASKS MANAGEMENT
  # ──────────────────────────────────────────────────────────────────────

  @doc """
  Lists all tasks for a supervisor across all their projects.
  Includes full preloading of attachee, user, and project data.
  """
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
  Lists all projects accessible by a supervisor.
  Based on the programs in their department.
  """
  def list_projects_for_supervisor(supervisor_id) do
    # Get supervisor's department
    case get_supervisor_department(supervisor_id) do
      nil ->
        []

      dept ->
        # Get programs in supervisor's department
        programs = list_programs_by_department(dept.id)
        program_ids = Enum.map(programs, & &1.id)

        if Enum.empty?(program_ids) do
          []
        else
          list_projects_by_programs(program_ids)
        end
    end
  end

  defp get_supervisor_department(supervisor_id) do
    user = Accounts.get_user!(supervisor_id)
    Orgs.get_department_for_user(user.id)
  end

  # ──────────────────────────────────────────────────────────────────────
  # TEAMS
  # ──────────────────────────────────────────────────────────────────────
  def create_team(attrs) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  # ──────────────────────────────────────────────────────────────────────
  # SUPERVISOR DASHBOARD HELPERS
  # ──────────────────────────────────────────────────────────────────────

  # ADDED: THIS IS THE ONLY NEW FUNCTION YOU WERE MISSING
  def count_projects_for_supervisor(supervisor_id) do
    supervisor_id
    |> list_projects_for_supervisor()
    |> length()
  end

  # OPTIONAL: Safer version of count_attachees_under_supervisor (won't crash if no teams exist)
  def count_attachees_under_supervisor(supervisor_id) do
    case get_supervisor_department(supervisor_id) do
      nil -> 0
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
      join: a in Attachee, on: task.assignee_id == a.id,
      join: tm in TeamMember, on: tm.user_id == a.user_id,
      join: t in Team, on: t.id == tm.team_id,
      where: t.supervisor_id == ^supervisor_id,
      where: task.status in ["pending", "in_progress"],
      select: count(task.id)
    )
    |> Repo.one() || 0
  end

  def count_pending_task_reviews(supervisor_id) do
    from(task in Task,
      join: a in Attachee, on: task.assignee_id == a.id,
      join: tm in TeamMember, on: tm.user_id == a.user_id,
      join: t in Team, on: t.id == tm.team_id,
      where: t.supervisor_id == ^supervisor_id,
      where: task.status == "submitted",
      select: count(task.id)
    )
    |> Repo.one() || 0
  end

  def count_completed_tasks_this_week(supervisor_id) do
    beginning_of_week = Date.utc_today() |> Date.beginning_of_week()
    start_of_week = DateTime.new!(beginning_of_week, ~T[00:00:00])

    from(task in Task,
      join: a in Attachee, on: task.assignee_id == a.id,
      join: tm in TeamMember, on: tm.user_id == a.user_id,
      join: t in Team, on: t.id == tm.team_id,
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
      join: a in Attachee, on: task.assignee_id == a.id,
      join: u in assoc(a, :user),
      join: tm in TeamMember, on: tm.user_id == a.user_id,
      join: t in Team, on: t.id == tm.team_id,
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

  # ──────────────────────────────────────────────────────────────────────
  # EVALUATIONS
  # ──────────────────────────────────────────────────────────────────────

  def create_evaluation(attrs, user_scope) do
    %Evaluation{}
    |> Evaluation.changeset(attrs, user_scope)
    |> Repo.insert()
  end

  @doc """
  Lists all evaluations for a specific attachee.
  """
  def list_evaluations_for_attachee(attachee_id, opts \\ %{}) do
    Evaluation
    |> where([e], e.attachee_id == ^attachee_id)
    |> order_by([e], desc: e.inserted_at)
    |> preload(^Map.get(opts, :preloads, [:evaluator]))
    |> Repo.all()
  end

  @doc """
  Gets a single evaluation.
  """
  def get_evaluation!(id, opts \\ %{}) do
    Evaluation
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:attachee, :evaluator]))
  end

  @doc """
  Updates an evaluation.
  """
  def update_evaluation(%Evaluation{} = evaluation, attrs, user_scope) do
    evaluation
    |> Evaluation.changeset(attrs, user_scope)
    |> Repo.update()
  end

  @doc """
  Deletes an evaluation.
  """
  def delete_evaluation(%Evaluation{} = evaluation) do
    Repo.delete(evaluation)
  end

  @doc """
  Gets the average evaluation score for an attachee, always returning a float.
  Handles Decimal values safely to avoid Float.round errors.
  """
  def get_average_evaluation_score(attachee_id) do
    from(e in Evaluation,
      where: e.attachee_id == ^attachee_id,
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

  @doc """
  Counts total evaluations for an attachee.
  """
  def count_evaluations_for_attachee(attachee_id) do
    from(e in Evaluation,
      where: e.attachee_id == ^attachee_id,
      select: count(e.id)
    )
    |> Repo.one() || 0
  end

  @doc """
  Gets the latest evaluation for an attachee.
  """
  def get_latest_evaluation_for_attachee(attachee_id) do
    from(e in Evaluation,
      where: e.attachee_id == ^attachee_id,
      order_by: [desc: e.inserted_at],
      limit: 1,
      preload: [:evaluator]
    )
    |> Repo.one()
  end

  @doc """
  Gets evaluation breakdown categories (for dashboard visualization).
  """
  def get_evaluation_categories_for_attachee(attachee_id) do
    # This returns a breakdown based on score ranges
    _evaluations = list_evaluations_for_attachee(attachee_id)
    avg_score = get_average_evaluation_score(attachee_id)

    # Generate category data based on average score
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
end
