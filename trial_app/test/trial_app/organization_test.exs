defmodule TrialApp.OrganizationTest do
  use TrialApp.DataCase

  alias TrialApp.Organization

  describe "departments" do
    alias TrialApp.Organization.Department

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationFixtures

    @invalid_attrs %{name: nil, description: nil}

    test "list_departments/1 returns all scoped departments" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      department = department_fixture(scope)
      other_department = department_fixture(other_scope)
      assert Organization.list_departments(scope) == [department]
      assert Organization.list_departments(other_scope) == [other_department]
    end

    test "get_department!/2 returns the department with given id" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organization.get_department!(scope, department.id) == department

      assert_raise Ecto.NoResultsError, fn ->
        Organization.get_department!(other_scope, department.id)
      end
    end

    test "create_department/2 with valid data creates a department" do
      valid_attrs = %{name: "some name", description: "some description"}
      scope = user_scope_fixture()

      assert {:ok, %Department{} = department} =
               Organization.create_department(scope, valid_attrs)

      assert department.name == "some name"
      assert department.description == "some description"
      assert department.user_id == scope.user.id
    end

    test "create_department/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organization.create_department(scope, @invalid_attrs)
    end

    test "update_department/3 with valid data updates the department" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      update_attrs = %{name: "some updated name", description: "some updated description"}

      assert {:ok, %Department{} = department} =
               Organization.update_department(scope, department, update_attrs)

      assert department.name == "some updated name"
      assert department.description == "some updated description"
    end

    test "update_department/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      department = department_fixture(scope)

      assert_raise MatchError, fn ->
        Organization.update_department(other_scope, department, %{})
      end
    end

    test "update_department/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      department = department_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Organization.update_department(scope, department, @invalid_attrs)

      assert department == Organization.get_department!(scope, department.id)
    end

    test "delete_department/2 deletes the department" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      assert {:ok, %Department{}} = Organization.delete_department(scope, department)

      assert_raise Ecto.NoResultsError, fn ->
        Organization.get_department!(scope, department.id)
      end
    end

    test "delete_department/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      department = department_fixture(scope)
      assert_raise MatchError, fn -> Organization.delete_department(other_scope, department) end
    end

    test "change_department/2 returns a department changeset" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      assert %Ecto.Changeset{} = Organization.change_department(scope, department)
    end
  end

  describe "teams" do
    alias TrialApp.Organization.Team

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationFixtures

    @invalid_attrs %{name: nil}

    test "list_teams/1 returns all scoped teams" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      team = team_fixture(scope)
      other_team = team_fixture(other_scope)
      assert Organization.list_teams(scope) == [team]
      assert Organization.list_teams(other_scope) == [other_team]
    end

    test "get_team!/2 returns the team with given id" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organization.get_team!(scope, team.id) == team
      assert_raise Ecto.NoResultsError, fn -> Organization.get_team!(other_scope, team.id) end
    end

    test "create_team/2 with valid data creates a team" do
      valid_attrs = %{name: "some name"}
      scope = user_scope_fixture()

      assert {:ok, %Team{} = team} = Organization.create_team(scope, valid_attrs)
      assert team.name == "some name"
      assert team.user_id == scope.user.id
    end

    test "create_team/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organization.create_team(scope, @invalid_attrs)
    end

    test "update_team/3 with valid data updates the team" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Team{} = team} = Organization.update_team(scope, team, update_attrs)
      assert team.name == "some updated name"
    end

    test "update_team/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      team = team_fixture(scope)

      assert_raise MatchError, fn ->
        Organization.update_team(other_scope, team, %{})
      end
    end

    test "update_team/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Organization.update_team(scope, team, @invalid_attrs)
      assert team == Organization.get_team!(scope, team.id)
    end

    test "delete_team/2 deletes the team" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      assert {:ok, %Team{}} = Organization.delete_team(scope, team)
      assert_raise Ecto.NoResultsError, fn -> Organization.get_team!(scope, team.id) end
    end

    test "delete_team/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      team = team_fixture(scope)
      assert_raise MatchError, fn -> Organization.delete_team(other_scope, team) end
    end

    test "change_team/2 returns a team changeset" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      assert %Ecto.Changeset{} = Organization.change_team(scope, team)
    end
  end

  describe "employees" do
    alias TrialApp.Organization.Employee

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationFixtures

    @invalid_attrs %{name: nil, role: nil, email: nil}

    test "list_employees/1 returns all scoped employees" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      employee = employee_fixture(scope)
      other_employee = employee_fixture(other_scope)
      assert Organization.list_employees(scope) == [employee]
      assert Organization.list_employees(other_scope) == [other_employee]
    end

    test "get_employee!/2 returns the employee with given id" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organization.get_employee!(scope, employee.id) == employee

      assert_raise Ecto.NoResultsError, fn ->
        Organization.get_employee!(other_scope, employee.id)
      end
    end

    test "create_employee/2 with valid data creates a employee" do
      valid_attrs = %{name: "some name", role: "some role", email: "some email"}
      scope = user_scope_fixture()

      assert {:ok, %Employee{} = employee} = Organization.create_employee(scope, valid_attrs)
      assert employee.name == "some name"
      assert employee.role == "some role"
      assert employee.email == "some email"
      assert employee.user_id == scope.user.id
    end

    test "create_employee/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organization.create_employee(scope, @invalid_attrs)
    end

    test "update_employee/3 with valid data updates the employee" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        role: "some updated role",
        email: "some updated email"
      }

      assert {:ok, %Employee{} = employee} =
               Organization.update_employee(scope, employee, update_attrs)

      assert employee.name == "some updated name"
      assert employee.role == "some updated role"
      assert employee.email == "some updated email"
    end

    test "update_employee/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      employee = employee_fixture(scope)

      assert_raise MatchError, fn ->
        Organization.update_employee(other_scope, employee, %{})
      end
    end

    test "update_employee/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Organization.update_employee(scope, employee, @invalid_attrs)

      assert employee == Organization.get_employee!(scope, employee.id)
    end

    test "delete_employee/2 deletes the employee" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert {:ok, %Employee{}} = Organization.delete_employee(scope, employee)
      assert_raise Ecto.NoResultsError, fn -> Organization.get_employee!(scope, employee.id) end
    end

    test "delete_employee/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert_raise MatchError, fn -> Organization.delete_employee(other_scope, employee) end
    end

    test "change_employee/2 returns a employee changeset" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert %Ecto.Changeset{} = Organization.change_employee(scope, employee)
    end
  end
end
