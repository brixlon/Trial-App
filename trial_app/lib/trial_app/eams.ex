defmodule TrialApp.Eams do
  @moduledoc """
  EAMS context: Programs, Projects, Attachees, Tasks, Teams, Supervisors.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Eams.{
    Program, Project, Task, Attachee, AttacheeProgram, Team, TeamMember
  }
  alias TrialApp.Orgs.{Department, Organization}
  alias TrialApp.Accounts.User

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

  def list_attachees_by_program(program_id, opts \\ %{}) do
    preloads = Map.get(opts, :preloads, [])

    from(a in Attachee,
      where: a.program_id == ^program_id,
      preload: ^preloads
    )
    |> Repo.all()
  end

  @doc """
  Lists all attachees assigned to tasks in a specific project.
  Returns attachees with their user information.
  """
  def list_attachees_in_project(project_id) do
    from(a in Attachee,
      join: t in Task, on: t.assignee_id == a.id,
      where: t.project_id == ^project_id,
      distinct: true,
      preload: [:user]
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

  def get_task!(id, opts \\ %{}) do
    Task
    |> Repo.get!(id)
    |> Repo.preload(Map.get(opts, :preloads, [:project, :assignee]))
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
  def submit_attachee_task(task_id, attrs) do
    task = get_task!(task_id, %{preloads: [:project, :assignee]})

    task
    |> Task.changeset(
      Map.merge(attrs, %{
        status: "submitted",
        submitted_at: DateTime.utc_now(),
        reject_reason: nil
      })
    )
    |> Repo.update()
  end

  def reject_attachee_task(task_id, reason) do
    task = get_task!(task_id, %{preloads: [:project, :assignee]})

    task
    |> Task.changeset(%{
      status: "rejected",
      reject_reason: reason
    })
    |> Repo.update()
  end

  def approve_attachee_task(task_id) do
    task = get_task!(task_id, %{preloads: [:project, :assignee]})

    task
    |> Task.changeset(%{
      status: "completed"
    })
    |> Repo.update()
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
  # TASK COMMENTS (Optional - uncomment when TaskComment schema is created)
  # ──────────────────────────────────────────────────────────────────────
  # def create_task_comment(attrs) do
  #   %TaskComment{}
  #   |> TaskComment.changeset(attrs)
  #   |> Repo.insert()
  # end

  # def list_task_comments(task_id) do
  #   TaskComment
  #   |> where([c], c.task_id == ^task_id)
  #   |> preload([:user])
  #   |> order_by([c], asc: c.inserted_at)
  #   |> Repo.all()
  # end

  # ──────────────────────────────────────────────────────────────────────
  # EVALUATIONS (Add Evaluation to aliases at top when schema is created)
  # ──────────────────────────────────────────────────────────────────────

  # Uncomment these after creating Evaluation schema with:
  # mix phx.gen.schema Eams.Evaluation evaluations attachee_id:references:attachees evaluator_id:references:users score:integer comments:text

  # def list_evaluations_for_attachee(attachee_id) do
  #   from(e in Evaluation,
  #     where: e.attachee_id == ^attachee_id,
  #     order_by: [desc: e.inserted_at],
  #     preload: [:evaluator, :attachee]
  #   )
  #   |> Repo.all()
  # end

  # def create_evaluation(attrs) do
  #   %Evaluation{}
  #   |> Evaluation.changeset(attrs)
  #   |> Repo.insert()
  # end

  # def get_evaluation!(id) do
  #   Evaluation
  #   |> Repo.get!(id)
  #   |> Repo.preload([:evaluator, :attachee])
  # end

  # ──────────────────────────────────────────────────────────────────────
  # SUPERVISOR DASHBOARD HELPERS
  # ──────────────────────────────────────────────────────────────────────
  def count_attachees_under_supervisor(supervisor_id) do
    from(a in Attachee,
      join: tm in TeamMember, on: tm.user_id == a.user_id,
      join: t in Team, on: t.id == tm.team_id,
      where: t.supervisor_id == ^supervisor_id,
      select: count(a.id)
    )
    |> Repo.one() || 0
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
end
