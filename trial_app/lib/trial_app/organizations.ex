defmodule TrialApp.Organizations do
  import Ecto.Query, warn: false
  alias TrialApp.Repo
  alias TrialApp.Organizations.Organization
  alias TrialApp.Departments.Department
  alias TrialApp.Teams.Team
  alias TrialApp.Employees.Employee

  # Organizations
  def list_organizations, do: Repo.all(Organization)
  def get_organization!(id), do: Repo.get!(Organization, id)
  def create_organization(attrs), do: %Organization{} |> Organization.changeset(attrs) |> Repo.insert()
  def update_organization(org, attrs), do: org |> Organization.changeset(attrs) |> Repo.update()
  def delete_organization(org), do: Repo.delete(org)

  # Departments
  def list_departments(org_id), do: Repo.all(from d in Department, where: d.organization_id == ^org_id)
  def get_department!(id), do: Repo.get!(Department, id)
  def create_department(attrs), do: %Department{} |> Department.changeset(attrs) |> Repo.insert()
  def update_department(dept, attrs), do: dept |> Department.changeset(attrs) |> Repo.update()
  def delete_department(dept), do: Repo.delete(dept)

  # Teams
  def list_teams(dept_id), do: Repo.all(from t in Team, where: t.department_id == ^dept_id)
  def get_team!(id), do: Repo.get!(Team, id)
  def create_team(attrs), do: %Team{} |> Team.changeset(attrs) |> Repo.insert()
  def update_team(team, attrs), do: team |> Team.changeset(attrs) |> Repo.update()
  def delete_team(team), do: Repo.delete(team)

  # Employees
  def list_employees(team_id), do: Repo.all(from e in Employee, where: e.team_id == ^team_id)
  def get_employee!(id), do: Repo.get!(Employee, id)
  def create_employee(attrs), do: %Employee{} |> Employee.changeset(attrs) |> Repo.insert()
  def update_employee(emp, attrs), do: emp |> Employee.changeset(attrs) |> Repo.update()
  def delete_employee(emp), do: Repo.delete(emp)
end
