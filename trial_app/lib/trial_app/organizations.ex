defmodule TrialApp.Organizations do
  @moduledoc """
  The Organizations context.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Organizations.{Organization, Department, Team, Employee, Position}
  alias TrialApp.Accounts.{User, Scope}

  # =======================
  # ORGANIZATIONS
  # =======================
  def list_organizations do
    Organization
    |> preload([departments: :teams])
    |> Repo.all()
  end

  def get_organization!(id), do: Repo.get!(Organization, id)

  def create_organization(attrs),
    do: %Organization{} |> Organization.changeset(attrs) |> Repo.insert()

  def update_organization(org, attrs),
    do: org |> Organization.changeset(attrs) |> Repo.update()

  def delete_organization(org), do: Repo.delete(org)

  # =======================
  # DEPARTMENTS
  # =======================
  def list_departments(org_id),
    do: Repo.all(from d in Department, where: d.organization_id == ^org_id)

  def list_all_departments do
    Department
    |> preload([:teams, :organization])
    |> Repo.all()
  end

  def get_department!(id), do: Repo.get!(Department, id)

  def get_department_with_teams!(id) do
    Repo.get!(Department, id)
    |> Repo.preload(:teams)
  end

  def create_department(attrs),
    do: %Department{} |> Department.changeset(attrs) |> Repo.insert()

  def update_department(dept, attrs),
    do: dept |> Department.changeset(attrs) |> Repo.update()

  def delete_department(dept), do: Repo.delete(dept)

  # =======================
  # TEAMS
  # =======================
  def list_teams(dept_id),
    do: Repo.all(from t in Team, where: t.department_id == ^dept_id)

  def list_all_teams do
    Team
    |> Repo.all()
    |> Repo.preload([
      :department,
      department: :organization,
      employees: [:user]
    ])
  end

  def get_team!(id), do: Repo.get!(Team, id)

  def get_team_with_employees!(id) do
    Repo.get!(Team, id)
    |> Repo.preload([:department, employees: :user])
  end

  def create_team(attrs),
    do: %Team{} |> Team.changeset(attrs) |> Repo.insert()

  def update_team(team, attrs),
    do: team |> Team.changeset(attrs) |> Repo.update()

  def delete_team(team), do: Repo.delete(team)

  # =======================
  # EMPLOYEES
  # =======================
  def list_employees(team_id),
    do: Repo.all(from e in Employee, where: e.team_id == ^team_id)

  def get_employee!(id), do: Repo.get!(Employee, id)

  def create_employee(attrs),
    do: %Employee{} |> Employee.changeset(attrs) |> Repo.insert()

  def update_employee(emp, attrs),
    do: emp |> Employee.changeset(attrs) |> Repo.update()

  def delete_employee(emp), do: Repo.delete(emp)

  def get_employee_with_user!(id) do
    Repo.get!(Employee, id)
    |> Repo.preload(:user)
  end

  def add_user_to_team(user_id, team_id) do
    team = get_team!(team_id) |> Repo.preload(:department)

    existing =
      Repo.one(from e in Employee,
        where: e.user_id == ^user_id and e.team_id == ^team_id
      )

    if existing do
      {:error, :already_exists}
    else
      %Employee{}
      |> Employee.changeset(%{
        user_id: user_id,
        team_id: team_id,
        department_id: team.department_id,
        is_active: true
      })
      |> Repo.insert()
    end
  end

  def remove_user_from_team(employee_id) do
    employee = get_employee!(employee_id)
    Repo.delete(employee)
  end

  # =======================
  # POSITIONS
  # =======================
  def list_positions, do: Repo.all(Position)
  def get_position!(id), do: Repo.get!(Position, id)
  def create_position(attrs), do: %Position{} |> Position.changeset(attrs) |> Repo.insert()
  def update_position(pos, attrs), do: pos |> Position.changeset(attrs) |> Repo.update()
  def delete_position(pos), do: Repo.delete(pos)

  # =======================
  # COUNTS & STATS
  # =======================
  def count_departments_for_organization(org_id) do
    Repo.one(from d in Department,
      where: d.organization_id == ^org_id,
      select: count(d.id)
    )
  end

  def count_teams_for_organization(org_id) do
    Repo.one(from t in Team,
      join: d in Department, on: t.department_id == d.id,
      where: d.organization_id == ^org_id,
      select: count(t.id)
    )
  end

  def count_all_employees, do: Repo.aggregate(Employee, :count, :id)

  # =======================
  # CURRENT USER HELPERS
  # =======================
  def get_user_department(%User{id: user_id}) do
    Repo.one(from d in Department,
      join: e in Employee, on: e.department_id == d.id,
      where: e.user_id == ^user_id,
      preload: [:organization]
    )
  end

  def get_user_team(%User{id: user_id}) do
    Repo.one(from t in Team,
      join: e in Employee, on: e.team_id == t.id,
      where: e.user_id == ^user_id,
      preload: [:department]
    )
  end

  def get_user_employee_info(%User{id: user_id}) do
    Repo.one(from e in Employee,
      where: e.user_id == ^user_id,
      preload: [:department, :team]
    )
  end
end
