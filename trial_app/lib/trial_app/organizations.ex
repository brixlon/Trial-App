defmodule TrialApp.Organizations do
  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Organizations.Organization
  alias TrialApp.Departments.Department
  alias TrialApp.Teams.Team
  alias TrialApp.Employees.Employee
  alias TrialApp.Accounts.User

  # =======================
  # ORGANIZATIONS
  # =======================
  def list_organizations, do: Repo.all(Organization)
  def get_organization!(id), do: Repo.get!(Organization, id)

  # Get organization with preloaded departments
  def get_organization_with_departments!(id) do
    Repo.get!(Organization, id)
    |> Repo.preload(:departments)
  end

  # Get all teams for an organization (across all departments)
  def list_teams_by_organization(org_id) do
    Repo.all(
      from t in Team,
        join: d in Department, on: t.department_id == d.id,
        where: d.organization_id == ^org_id,
        preload: [:department]
    )
  end

  def create_organization(attrs), do: %Organization{} |> Organization.changeset(attrs) |> Repo.insert()
  def update_organization(org, attrs), do: org |> Organization.changeset(attrs) |> Repo.update()
  def delete_organization(org), do: Repo.delete(org)

  # =======================
  # DEPARTMENTS
  # =======================
  def list_departments(org_id), do: Repo.all(from d in Department, where: d.organization_id == ^org_id)
  def get_department!(id), do: Repo.get!(Department, id)

  # Get department with teams
  def get_department_with_teams!(id) do
    Repo.get!(Department, id)
    |> Repo.preload(:teams)
  end

  def create_department(attrs), do: %Department{} |> Department.changeset(attrs) |> Repo.insert()
  def update_department(dept, attrs), do: dept |> Department.changeset(attrs) |> Repo.update()
  def delete_department(dept), do: Repo.delete(dept)

  # =======================
  # TEAMS
  # =======================
  def list_teams(dept_id), do: Repo.all(from t in Team, where: t.department_id == ^dept_id)
  def get_team!(id), do: Repo.get!(Team, id)

  # Get team with employees
  def get_team_with_employees!(id) do
    Repo.get!(Team, id)
    |> Repo.preload([:employees, :department])
  end

  def create_team(attrs), do: %Team{} |> Team.changeset(attrs) |> Repo.insert()
  def update_team(team, attrs), do: team |> Team.changeset(attrs) |> Repo.update()
  def delete_team(team), do: Repo.delete(team)

  # =======================
  # EMPLOYEES
  # =======================
  def list_employees(team_id), do: Repo.all(from e in Employee, where: e.team_id == ^team_id)
  def get_employee!(id), do: Repo.get!(Employee, id)
  def create_employee(attrs), do: %Employee{} |> Employee.changeset(attrs) |> Repo.insert()
  def update_employee(emp, attrs), do: emp |> Employee.changeset(attrs) |> Repo.update()
  def delete_employee(emp), do: Repo.delete(emp)

  # =======================
  # COUNTING FUNCTIONS
  # =======================

  # Count departments for organization
  def count_departments_for_organization(org_id) do
    Repo.one(
      from d in Department,
      where: d.organization_id == ^org_id,
      select: count(d.id)
    )
  end

  # Count teams for organization
  def count_teams_for_organization(org_id) do
    Repo.one(
      from t in Team,
      join: d in Department, on: t.department_id == d.id,
      where: d.organization_id == ^org_id,
      select: count(t.id)
    )
  end

  # Count all employees
  def count_all_employees, do: Repo.aggregate(Employee, :count, :id)

  # =======================
  # HELPER FUNCTIONS (For current user)
  # =======================

  # Fetch department of current user
  def get_user_department(%User{id: user_id}) do
    Repo.one(
      from d in Department,
        join: e in Employee, on: e.department_id == d.id,
        where: e.user_id == ^user_id,
        preload: [:organization]
    )
  end

  # Fetch team of current user
  def get_user_team(%User{id: user_id}) do
    Repo.one(
      from t in Team,
        join: e in Employee, on: e.team_id == t.id,
        where: e.user_id == ^user_id,
        preload: [:department]
    )
  end

  # Fetch employee record for current user (includes department + position)
  def get_user_employee_info(%User{id: user_id}) do
    Repo.one(
      from e in Employee,
        where: e.user_id == ^user_id,
        preload: [:department, :team]
    )
  end
end
