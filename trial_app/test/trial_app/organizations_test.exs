defmodule TrialApp.OrganizationsTest do
  use TrialApp.DataCase

  alias TrialApp.Organizations

  describe "departments" do
    alias TrialApp.Organizations.Department

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationsFixtures

    @invalid_attrs %{name: nil, description: nil}

    test "list_departments/1 returns all scoped departments" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      department = department_fixture(scope)
      other_department = department_fixture(other_scope)
      assert Organizations.list_departments(scope) == [department]
      assert Organizations.list_departments(other_scope) == [other_department]
    end

    test "get_department!/2 returns the department with given id" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organizations.get_department!(scope, department.id) == department
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_department!(other_scope, department.id) end
    end

    test "create_department/2 with valid data creates a department" do
      valid_attrs = %{name: "some name", description: "some description"}
      scope = user_scope_fixture()

      assert {:ok, %Department{} = department} = Organizations.create_department(scope, valid_attrs)
      assert department.name == "some name"
      assert department.description == "some description"
      assert department.user_id == scope.user.id
    end

    test "create_department/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organizations.create_department(scope, @invalid_attrs)
    end

    test "update_department/3 with valid data updates the department" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      update_attrs = %{name: "some updated name", description: "some updated description"}

      assert {:ok, %Department{} = department} = Organizations.update_department(scope, department, update_attrs)
      assert department.name == "some updated name"
      assert department.description == "some updated description"
    end

    test "update_department/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      department = department_fixture(scope)

      assert_raise MatchError, fn ->
        Organizations.update_department(other_scope, department, %{})
      end
    end

    test "update_department/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Organizations.update_department(scope, department, @invalid_attrs)
      assert department == Organizations.get_department!(scope, department.id)
    end

    test "delete_department/2 deletes the department" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      assert {:ok, %Department{}} = Organizations.delete_department(scope, department)
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_department!(scope, department.id) end
    end

    test "delete_department/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      department = department_fixture(scope)
      assert_raise MatchError, fn -> Organizations.delete_department(other_scope, department) end
    end

    test "change_department/2 returns a department changeset" do
      scope = user_scope_fixture()
      department = department_fixture(scope)
      assert %Ecto.Changeset{} = Organizations.change_department(scope, department)
    end
  end

  describe "teams" do
    alias TrialApp.Organizations.Team

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationsFixtures

    @invalid_attrs %{name: nil, description: nil}

    test "list_teams/1 returns all scoped teams" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      team = team_fixture(scope)
      other_team = team_fixture(other_scope)
      assert Organizations.list_teams(scope) == [team]
      assert Organizations.list_teams(other_scope) == [other_team]
    end

    test "get_team!/2 returns the team with given id" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organizations.get_team!(scope, team.id) == team
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_team!(other_scope, team.id) end
    end

    test "create_team/2 with valid data creates a team" do
      valid_attrs = %{name: "some name", description: "some description"}
      scope = user_scope_fixture()

      assert {:ok, %Team{} = team} = Organizations.create_team(scope, valid_attrs)
      assert team.name == "some name"
      assert team.description == "some description"
      assert team.user_id == scope.user.id
    end

    test "create_team/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organizations.create_team(scope, @invalid_attrs)
    end

    test "update_team/3 with valid data updates the team" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      update_attrs = %{name: "some updated name", description: "some updated description"}

      assert {:ok, %Team{} = team} = Organizations.update_team(scope, team, update_attrs)
      assert team.name == "some updated name"
      assert team.description == "some updated description"
    end

    test "update_team/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      team = team_fixture(scope)

      assert_raise MatchError, fn ->
        Organizations.update_team(other_scope, team, %{})
      end
    end

    test "update_team/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Organizations.update_team(scope, team, @invalid_attrs)
      assert team == Organizations.get_team!(scope, team.id)
    end

    test "delete_team/2 deletes the team" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      assert {:ok, %Team{}} = Organizations.delete_team(scope, team)
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_team!(scope, team.id) end
    end

    test "delete_team/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      team = team_fixture(scope)
      assert_raise MatchError, fn -> Organizations.delete_team(other_scope, team) end
    end

    test "change_team/2 returns a team changeset" do
      scope = user_scope_fixture()
      team = team_fixture(scope)
      assert %Ecto.Changeset{} = Organizations.change_team(scope, team)
    end
  end

  describe "employees" do
    alias TrialApp.Organizations.Employee

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationsFixtures

    @invalid_attrs %{name: nil, position: nil, email: nil}

    test "list_employees/1 returns all scoped employees" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      employee = employee_fixture(scope)
      other_employee = employee_fixture(other_scope)
      assert Organizations.list_employees(scope) == [employee]
      assert Organizations.list_employees(other_scope) == [other_employee]
    end

    test "get_employee!/2 returns the employee with given id" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organizations.get_employee!(scope, employee.id) == employee
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_employee!(other_scope, employee.id) end
    end

    test "create_employee/2 with valid data creates a employee" do
      valid_attrs = %{name: "some name", position: "some position", email: "some email"}
      scope = user_scope_fixture()

      assert {:ok, %Employee{} = employee} = Organizations.create_employee(scope, valid_attrs)
      assert employee.name == "some name"
      assert employee.position == "some position"
      assert employee.email == "some email"
      assert employee.user_id == scope.user.id
    end

    test "create_employee/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organizations.create_employee(scope, @invalid_attrs)
    end

    test "update_employee/3 with valid data updates the employee" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      update_attrs = %{name: "some updated name", position: "some updated position", email: "some updated email"}

      assert {:ok, %Employee{} = employee} = Organizations.update_employee(scope, employee, update_attrs)
      assert employee.name == "some updated name"
      assert employee.position == "some updated position"
      assert employee.email == "some updated email"
    end

    test "update_employee/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      employee = employee_fixture(scope)

      assert_raise MatchError, fn ->
        Organizations.update_employee(other_scope, employee, %{})
      end
    end

    test "update_employee/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Organizations.update_employee(scope, employee, @invalid_attrs)
      assert employee == Organizations.get_employee!(scope, employee.id)
    end

    test "delete_employee/2 deletes the employee" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert {:ok, %Employee{}} = Organizations.delete_employee(scope, employee)
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_employee!(scope, employee.id) end
    end

    test "delete_employee/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert_raise MatchError, fn -> Organizations.delete_employee(other_scope, employee) end
    end

    test "change_employee/2 returns a employee changeset" do
      scope = user_scope_fixture()
      employee = employee_fixture(scope)
      assert %Ecto.Changeset{} = Organizations.change_employee(scope, employee)
    end
  end

  describe "positions" do
    alias TrialApp.Organizations.Position

    import TrialApp.AccountsFixtures, only: [user_scope_fixture: 0]
    import TrialApp.OrganizationsFixtures

    @invalid_attrs %{description: nil, title: nil}

    test "list_positions/1 returns all scoped positions" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      position = position_fixture(scope)
      other_position = position_fixture(other_scope)
      assert Organizations.list_positions(scope) == [position]
      assert Organizations.list_positions(other_scope) == [other_position]
    end

    test "get_position!/2 returns the position with given id" do
      scope = user_scope_fixture()
      position = position_fixture(scope)
      other_scope = user_scope_fixture()
      assert Organizations.get_position!(scope, position.id) == position
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_position!(other_scope, position.id) end
    end

    test "create_position/2 with valid data creates a position" do
      valid_attrs = %{description: "some description", title: "some title"}
      scope = user_scope_fixture()

      assert {:ok, %Position{} = position} = Organizations.create_position(scope, valid_attrs)
      assert position.description == "some description"
      assert position.title == "some title"
      assert position.user_id == scope.user.id
    end

    test "create_position/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Organizations.create_position(scope, @invalid_attrs)
    end

    test "update_position/3 with valid data updates the position" do
      scope = user_scope_fixture()
      position = position_fixture(scope)
      update_attrs = %{description: "some updated description", title: "some updated title"}

      assert {:ok, %Position{} = position} = Organizations.update_position(scope, position, update_attrs)
      assert position.description == "some updated description"
      assert position.title == "some updated title"
    end

    test "update_position/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      position = position_fixture(scope)

      assert_raise MatchError, fn ->
        Organizations.update_position(other_scope, position, %{})
      end
    end

    test "update_position/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      position = position_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Organizations.update_position(scope, position, @invalid_attrs)
      assert position == Organizations.get_position!(scope, position.id)
    end

    test "delete_position/2 deletes the position" do
      scope = user_scope_fixture()
      position = position_fixture(scope)
      assert {:ok, %Position{}} = Organizations.delete_position(scope, position)
      assert_raise Ecto.NoResultsError, fn -> Organizations.get_position!(scope, position.id) end
    end

    test "delete_position/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      position = position_fixture(scope)
      assert_raise MatchError, fn -> Organizations.delete_position(other_scope, position) end
    end

    test "change_position/2 returns a position changeset" do
      scope = user_scope_fixture()
      position = position_fixture(scope)
      assert %Ecto.Changeset{} = Organizations.change_position(scope, position)
    end
  end
end
