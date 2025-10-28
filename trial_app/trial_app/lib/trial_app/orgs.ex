defmodule TrialApp.Orgs do
  @moduledoc """
  The Orgs context handles organizations, departments, teams, and employees.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo
  alias TrialApp.Orgs.{Organization, Department, Team, Employee, Position}

  # ----------------------------
  # ORGANIZATIONS - ENHANCED
  # ----------------------------

  def list_organizations do
    Organization
    |> where([o], o.is_active == true)
    |> preload([:departments, :teams, :employees])
    |> Repo.all()
  end

  def list_all_organizations do
    Organization
    |> preload([:departments, :teams, :employees])
    |> Repo.all()
  end

  def get_organization!(id) do
    Organization
    |> where([o], o.id == ^id)
    |> preload(departments: [:teams, :employees])
    |> Repo.one!()
  end

  def get_organization_with_departments!(id) do
    Organization
    |> where(id: ^id)
    |> preload([:departments, :teams, :employees])
    |> Repo.one!()
  end

  def create_organization(attrs) do
    %Organization{}
    |> Organization.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_organization(%Organization{} = org, attrs) do
    org
    |> Organization.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_organization(%Organization{} = org) do
    # Soft delete - set is_active to false
    update_organization(org, %{is_active: false})
  end

  # ----------------------------
  # DEPARTMENTS - ENHANCED
  # ----------------------------

  def list_departments do
    Department
    |> where([d], d.is_active == true)
    |> preload([:organization, :teams, :employees])
    |> Repo.all()
  end

  def list_departments_by_org(org_id) do
    Department
    |> where([d], d.organization_id == ^org_id and d.is_active == true)
    |> preload([:organization, :teams, :employees])
    |> Repo.all()
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
    |> Department.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_department(%Department{} = department, attrs) do
    department
    |> Department.changeset(attrs)
    |> Repo.update()
  end

  def delete_department(%Department{} = department) do
    # Soft delete - set is_active to false
    update_department(department, %{is_active: false})
  end

  # ----------------------------
  # TEAMS - ENHANCED
  # ----------------------------

  def list_teams do
    Team
    |> where([t], t.is_active == true)
    |> preload([:department, :organization, :employees])
    |> Repo.all()
  end

  def get_team_with_preloads!(id) do
    Team
    |> where(id: ^id)
    |> preload([:department, :organization, employees: [:user]])
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
    |> where([t], t.department_id == ^department_id and t.is_active == true)
    |> preload([:department, :organization, :employees])
    |> Repo.all()
  end

  # Alias for consistency
  def list_teams_by_department(department_id), do: list_teams_by_dept(department_id)

  def list_teams_by_organization(org_id) do
    Team
    |> join(:inner, [t], d in Department, on: t.department_id == d.id)
    |> where([t, d], d.organization_id == ^org_id and t.is_active == true)
    |> preload([:department, :organization, :employees])
    |> Repo.all()
  end

  def get_team!(id), do: Repo.get!(Team, id)

  def create_team(attrs) do
    %Team{}
    |> Team.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  def delete_team(%Team{} = team) do
    # Soft delete - set is_active to false
    update_team(team, %{is_active: false})
  end

  # ----------------------------
  # EMPLOYEES - ENHANCED
  # ----------------------------

  def list_employees do
    Employee
    |> where([e], e.is_active == true)
    |> preload([:user, :team, :department, :organization])
    |> Repo.all()
  end

  # ----------------------------
  # POSITIONS
  # ----------------------------

  def list_positions do
    Position
    |> where([p], p.is_active == true)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def search_positions(term) when is_binary(term) do
    like = "%" <> term <> "%"
    Position
    |> where([p], ilike(p.name, ^like) or ilike(p.description, ^like))
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def get_position!(id), do: Repo.get!(Position, id)

  def create_position(attrs) do
    %Position{}
    |> Position.changeset(attrs)
    |> Repo.insert()
  end

  def update_position(%Position{} = position, attrs) do
    position
    |> Position.changeset(attrs)
    |> Repo.update()
  end

  def delete_position(%Position{} = position) do
    update_position(position, %{is_active: false})
  end

  def list_all_employees do
    Employee
    |> preload([:user, :team, :department, :organization])
    |> Repo.all()
  end

  def list_employees_by_team(team_id) do
    Employee
    |> where([e], e.team_id == ^team_id and e.is_active == true)
    |> preload([:user, :team, :department, :organization])
    |> Repo.all()
  end

  def list_employees_by_user(user_id) do
    Employee
    |> where([e], e.user_id == ^user_id and e.is_active == true)
    |> preload([:user, :team, :department, :organization])
    |> Repo.all()
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
    |> Employee.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_employee(%Employee{} = employee, attrs) do
    employee
    |> Employee.changeset(attrs)
    |> Repo.update()
  end

  def delete_employee(%Employee{} = employee) do
    # Soft delete - set is_active to false
    update_employee(employee, %{is_active: false})
  end

  def delete_employee_by_user_and_team(user_id, team_id) do
    Repo.delete_all(from(e in Employee, where: e.user_id == ^user_id and e.team_id == ^team_id))
  end

  # ----------------------------
  # MULTI-TEAM SUPPORT FUNCTIONS
  # ----------------------------

  def create_employee_for_teams(user_attrs, team_ids) when is_list(team_ids) do
    Repo.transaction(fn ->
      Enum.map(team_ids, fn team_id ->
        team = get_team_with_preloads!(team_id)

        employee_attrs =
          Map.merge(user_attrs, %{
            team_id: team_id,
            department_id: team.department_id,
            organization_id: team.department.organization_id
          })

        %Employee{}
        |> Employee.create_changeset(employee_attrs)
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
          role: "member",
          position: "Team Member",
          is_active: true,
          status: "active"
        }

        create_employee(employee_attrs)
      end)
    end)
  end

  # ----------------------------
  # ENHANCED ADMIN FUNCTIONS
  # ----------------------------

  @doc """
  Get organization with full hierarchy for admin dashboard.
  """
  def get_organization_full_hierarchy!(id) do
    Organization
    |> where(id: ^id)
    |> preload(
      departments: [
        teams: [
          employees: [:user]
        ]
      ],
      employees: [:user, :team, :department]
    )
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
  def move_employee(employee_id, %{
        organization_id: org_id,
        department_id: dept_id,
        team_id: team_id
      }) do
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
      join: d in Department,
      on: t.department_id == d.id,
      where: d.organization_id in ^user_orgs and t.is_active == true,
      preload: [:department, :organization]
    )
    |> Repo.all()
  end

  @doc """
  Bulk update employee roles for a team.
  """
  def update_team_roles(_team_id, role_updates) when is_list(role_updates) do
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
    |> preload([:department, :organization, :employees, :team_lead])
    |> Repo.one!()
  end

  @doc """
  Assign team lead and update employee role.
  """
  def assign_team_lead(team_id, user_id) do
    Repo.transaction(fn ->
      team = get_team!(team_id)

      # Update team with new team lead
      {:ok, team} = update_team(team, %{team_lead_id: user_id})

      # Find or create employee record for team lead
      employee =
        from(e in Employee,
          where: e.team_id == ^team_id and e.user_id == ^user_id
        )
        |> Repo.one()

      if employee do
        update_employee(employee, %{role: "lead"})
      else
        user = TrialApp.Accounts.get_user!(user_id)

        employee_attrs = %{
          user_id: user_id,
          team_id: team_id,
          department_id: team.department_id,
          organization_id: team.organization_id,
          name: user.username || user.email,
          email: user.email,
          role: "lead",
          position: "Team Lead",
          is_active: true,
          status: "active"
        }

        create_employee(employee_attrs)
      end

      team
    end)
  end

  @doc """
  Get statistics for admin dashboard.
  """
  def get_dashboard_stats do
    org_count =
      from(o in Organization, where: o.is_active == true)
      |> Repo.aggregate(:count, :id)

    dept_count =
      from(d in Department, where: d.is_active == true)
      |> Repo.aggregate(:count, :id)

    team_count =
      from(t in Team, where: t.is_active == true)
      |> Repo.aggregate(:count, :id)

    employee_count =
      from(e in Employee, where: e.is_active == true)
      |> Repo.aggregate(:count, :id)

    %{
      organizations: org_count,
      departments: dept_count,
      teams: team_count,
      employees: employee_count
    }
  end

  @doc """
  Search employees by name, email, or position.
  """
  def search_employees(search_term) when is_binary(search_term) do
    search_term = "%#{search_term}%"

    from(e in Employee,
      where:
        ilike(e.name, ^search_term) or
          ilike(e.email, ^search_term) or
          ilike(e.position, ^search_term),
      where: e.is_active == true,
      preload: [:user, :team, :department, :organization]
    )
    |> Repo.all()
  end

  @doc """
  Get teams with employee counts for dashboard.
  """
  def teams_with_employee_counts do
    from(t in Team,
      where: t.is_active == true,
      left_join: e in Employee,
      on: e.team_id == t.id and e.is_active == true,
      group_by: t.id,
      preload: [:department, :organization],
      select: {t, fragment("COUNT(?)", e.id)}
    )
    |> Repo.all()
  end
end
