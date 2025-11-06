defmodule TrialApp.Eams do
  @moduledoc """
  EAMS context: Programs, Projects, Attachees, and Tasks.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Eams.{Program, Project, Task, Attachee, AttacheeProgram}
  alias TrialApp.Orgs.{Department, Organization}

  # Programs
  def list_programs(opts \\ %{}) do
    Program |> preload(^Map.get(opts, :preloads, [:department, :organization])) |> Repo.all()
  end

  def list_programs_by_department(department_id, opts \\ %{}) do
    Program
    |> where([p], p.department_id == ^department_id)
    |> preload(^Map.get(opts, :preloads, [:department, :organization]))
    |> Repo.all()
  end

  def get_program!(id, opts \\ %{}) do
    Program |> Repo.get!(id) |> Repo.preload(Map.get(opts, :preloads, [:department, :organization]))
  end

  def create_program(attrs) do
    %Program{} |> Program.create_changeset(attrs) |> Repo.insert()
  end

  def update_program(%Program{} = program, attrs) do
    program |> Program.update_changeset(attrs) |> Repo.update()
  end

  def delete_program(%Program{} = program), do: Repo.delete(program)

  # Projects
  def list_projects(opts \\ %{}) do
    Project |> preload(^Map.get(opts, :preloads, [:program, :department, :organization])) |> Repo.all()
  end

  def list_projects_by_program(program_id, opts \\ %{}) do
    Project
    |> where([p], p.program_id == ^program_id)
    |> preload(^Map.get(opts, :preloads, [:program, :department, :organization]))
    |> Repo.all()
  end

  def get_project!(id, opts \\ %{}) do
    Project |> Repo.get!(id) |> Repo.preload(Map.get(opts, :preloads, [:program, :department, :organization]))
  end

  def create_project(attrs) do
    %Project{} |> Project.create_changeset(attrs) |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project |> Project.update_changeset(attrs) |> Repo.update()
  end

  def delete_project(%Project{} = project), do: Repo.delete(project)

  # Attachees
  def list_attachees(opts \\ %{}) do
    Attachee |> preload(^Map.get(opts, :preloads, [:user, :department, :organization])) |> Repo.all()
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

  def enroll_attachee_in_program(attachee_id, program_id) do
    %AttacheeProgram{}
    |> AttacheeProgram.changeset(%{attachee_id: attachee_id, program_id: program_id})
    |> Repo.insert()
  end

  # ————————————————————————————
  # Current user helpers
  # ————————————————————————————
  def get_attachee_by_user!(user_id) do
    Attachee
    |> where([a], a.user_id == ^user_id)
    |> preload([:user, :department, :organization])
    |> Repo.one!()
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
    |> preload([:project])
    |> Repo.all()
  end

  def list_projects_for_attachee(attachee_id) do
    from(pr in Project,
      join: t in Task,
      on: t.project_id == pr.id,
      where: t.assignee_id == ^attachee_id,
      distinct: true
    )
    |> Repo.all()
  end

  def get_attachee!(id, opts \\ %{}) do
    Attachee |> Repo.get!(id) |> Repo.preload(Map.get(opts, :preloads, [:user, :department, :organization]))
  end

  def create_attachee(attrs) do
    %Attachee{} |> Attachee.create_changeset(attrs) |> Repo.insert()
  end

  def update_attachee(%Attachee{} = attachee, attrs) do
    attachee |> Attachee.update_changeset(attrs) |> Repo.update()
  end

  def delete_attachee(%Attachee{} = attachee), do: Repo.delete(attachee)

  # Tasks
  def list_tasks(opts \\ %{}) do
    Task |> preload(^Map.get(opts, :preloads, [:project, :assignee])) |> Repo.all()
  end

  def get_task!(id, opts \\ %{}) do
    Task |> Repo.get!(id) |> Repo.preload(Map.get(opts, :preloads, [:project, :assignee]))
  end

  def create_task(attrs) do
    %Task{} |> Task.create_changeset(attrs) |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task |> Task.update_changeset(attrs) |> Repo.update()
  end

  def delete_task(%Task{} = task), do: Repo.delete(task)
end
