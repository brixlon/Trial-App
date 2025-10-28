defmodule TrialApp.Orgs do
  @moduledoc """
  The Orgs context handles organizations, departments, teams, and employees.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo
  alias TrialApp.Orgs.{Organization, Department, Team, Employee}

  # ----------------------------
  # ORGANIZATIONS
  # ----------------------------

  def list_organizations do
    Repo.all(Organization)
    |> Repo.preload([:departments, :teams, :employees])
  end

  def get_organization!(id) do
    Repo.get!(Organization, id)
    |> Repo.preload(departments: [:teams, :employees])
  end

  def get_organization_with_departments!(id) do
    Organization
    |> where(id: ^id)
    |> preload([:departments, :teams, :employees])
    |> Repo.one!()
  end

  def create_organization(attrs) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
  end

  def update_organization(%Organization{} = org, attrs) do
    org
    |> Organization.changeset(attrs)
    |> Repo.update()
  end

  def delete_organization(%Organization{} = org) do
    Repo.delete(org)
  end

  # ----------------------------
  # DEPARTMENTS
  # ----------------------------

  def list_departments do
    Repo.all(Department)
    |> Repo.preload([:organization, :teams, :employees])
  end

  def list_departments_by_org(org_id) do
    Department
    |> where(organization_id: ^org_id)
    |> Repo.all()
    |> Repo.preload([:organization, :teams, :employees])
  end

  def get_department_with_teams!(id) do
    Department
    |> where(id: ^id)
    |> preload([:teams, :employees, :organization])
    |> Repo.one!()
  end

  def get_department!(id), do: Repo.get!(Department, id)

  def create_department(attrs) do
    %Department{}
    |> Department.changeset(attrs)
    |> Repo.insert()
  end

  def update_department(%Department{} = department, attrs) do
    department
    |> Department.changeset(attrs)
    |> Repo.update()
  end

  def delete_department(%Department{} = department) do
    Repo.delete(department)
  end

  # ----------------------------
  # TEAMS
  # ----------------------------

  def list_teams do
    Repo.all(Team)
    |> Repo.preload([:department, :employees])
  end

  def get_team_with_preloads!(id) do
    Team
    |> where(id: ^id)
    |> preload([:department, employees: [:user]])
    |> Repo.one!()
  end

  def get_team_with_employees!(id) do
    Team
    |> where(id: ^id)
    |> preload([:employees, department: [:organization]])
    |> Repo.one!()
  end

  def list_teams_by_dept(department_id) do
    Team
    |> where(department_id: ^department_id)
    |> Repo.all()
    |> Repo.preload([:department, :employees])
  end

  # Alias for consistency
  def list_teams_by_department(department_id), do: list_teams_by_dept(department_id)

  def list_teams_by_organization(org_id) do
    Team
    |> join(:inner, [t], d in Department, on: t.department_id == d.id)
    |> where([t, d], d.organization_id == ^org_id)
    |> preload([:department, :employees])
    |> Repo.all()
  end

  def get_team!(id), do: Repo.get!(Team, id)

  def create_team(attrs) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  def delete_team(%Team{} = team) do
    Repo.delete(team)
  end

  # ----------------------------
  # EMPLOYEES
  # ----------------------------

  def list_employees do
    Repo.all(Employee)
    |> Repo.preload([:user, :team, :department, :organization])
  end

  def list_employees_by_team(team_id) do
    Employee
    |> where(team_id: ^team_id)
    |> Repo.all()
    |> Repo.preload([:user, :team, :department, :organization])
  end

  def list_employees_by_user(user_id) do
    Employee
    |> where(user_id: ^user_id)
    |> Repo.all()
    |> Repo.preload([:user, :team, :department, :organization])
  end

  def get_employee!(id), do: Repo.get!(Employee, id)

  def get_employee_with_preloads!(id) do
    Employee
    |> where(id: ^id)
    |> preload([:user, :team, :department, :organization])
    |> Repo.one!()
  end

  def create_employee(attrs) do
    %Employee{}
    |> Employee.changeset(attrs)
    |> Repo.insert()
  end

  def update_employee(%Employee{} = employee, attrs) do
    employee
    |> Employee.changeset(attrs)
    |> Repo.update()
  end

  def delete_employee(%Employee{} = employee) do
    Repo.delete(employee)
  end

  def delete_employee_by_user_and_team(user_id, team_id) do
    Repo.delete_all(from(e in Employee, where: e.user_id == ^user_id and e.team_id == ^team_id))
  end

  # Multi-team support functions
  def create_employee_for_teams(user_attrs, team_ids) when is_list(team_ids) do
    Repo.transaction(fn ->
      Enum.map(team_ids, fn team_id ->
        team = get_team_with_preloads!(team_id)

        employee_attrs = Map.merge(user_attrs, %{
          team_id: team_id,
          department_id: team.department_id,
          organization_id: team.department.organization_id
        })

        %Employee{}
        |> Employee.changeset(employee_attrs)
        |> Repo.insert!()
      end)
    end)
  end

  def update_employee_teams(user_id, team_ids) do
    Repo.transaction(fn ->
      # Delete existing employee records for this user
      Repo.delete_all(from(e in Employee, where: e.user_id == ^user_id))

      # Create new employee records for selected teams
      Enum.each(team_ids, fn team_id ->
        team = get_team_with_preloads!(team_id)
        user = TrialApp.Accounts.get_user!(user_id)

        employee_attrs = %{
          user_id: user_id,
          name: user.username || user.email,
          email: user.email,
          team_id: team_id,
          department_id: team.department_id,
          organization_id: team.department.organization_id,
          role: user.assigned_role || "user",
          position: user.assigned_position || "Employee"
        }

        create_employee(employee_attrs)
      end)
    end)
  end

  # ----------------------------
  # ENHANCED QUERIES FOR ADMIN DASHBOARD
  # ----------------------------

  @doc """
  Get organization with full hierarchy for admin dashboard.
  """
  def get_organization_full_hierarchy!(id) do
    Organization
    |> where(id: ^id)
    |> preload([
      departments: [
        teams: [
          employees: [:user]
        ]
      ],
      employees: [:user, :team, :department]
    ])
    |> Repo.one!()
  end

  @doc """
  Get user with all employee assignments and their organizations/departments/teams.
  """
  def get_user_with_assignments!(user_id) do
    TrialApp.Accounts.get_user!(user_id)
    |> Repo.preload(employees: [:team, :department, :organization])
  end

  @doc """
  Move employee to different organization/department/team.
  """
  def move_employee(employee_id, %{organization_id: org_id, department_id: dept_id, team_id: team_id}) do
    employee = get_employee_with_preloads!(employee_id)

    update_employee(employee, %{
      organization_id: org_id,
      department_id: dept_id,
      team_id: team_id
    })
  end

  @doc """
  Get all available teams for a user to join (based on their current organizations).
  """
  def get_available_teams_for_user(user_id) do
    # Get user's current organizations through existing employees
    user_orgs =
      from(e in Employee,
        where: e.user_id == ^user_id,
        select: e.organization_id
      )
      |> Repo.all()

    # Get all teams from those organizations
    from(t in Team,
      join: d in Department, on: t.department_id == d.id,
      where: d.organization_id in ^user_orgs,
      preload: [:department]
    )
    |> Repo.all()
  end

  @doc """
  Bulk update employee roles for a team.
  """
  def update_team_roles(team_id, role_updates) when is_list(role_updates) do
    Repo.transaction(fn ->
      Enum.each(role_updates, fn %{employee_id: emp_id, role: new_role} ->
        employee = get_employee!(emp_id)
        update_employee(employee, %{role: new_role})
      end)
    end)
  end

  @doc """
  Get team with department and organization preloaded.
  """
  def get_team_with_full_hierarchy!(id) do
    Team
    |> where(id: ^id)
    |> preload([:department, :employees, :team_lead])
    |> Repo.one!()
  end
end
