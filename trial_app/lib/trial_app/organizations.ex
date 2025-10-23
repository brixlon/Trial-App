defmodule TrialApp.Organizations do
  @moduledoc """
  The Organizations context.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Organizations.Department
  alias TrialApp.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any department changes.

  The broadcasted messages match the pattern:

    * {:created, %Department{}}
    * {:updated, %Department{}}
    * {:deleted, %Department{}}

  """
  def subscribe_departments(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(TrialApp.PubSub, "user:#{key}:departments")
  end

  defp broadcast_department(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(TrialApp.PubSub, "user:#{key}:departments", message)
  end

  @doc """
  Returns the list of departments.

  ## Examples

      iex> list_departments(scope)
      [%Department{}, ...]

  """
  def list_departments(%Scope{} = scope) do
    Repo.all_by(Department, user_id: scope.user.id)
  end

  @doc """
  Gets a single department.

  Raises `Ecto.NoResultsError` if the Department does not exist.

  ## Examples

      iex> get_department!(scope, 123)
      %Department{}

      iex> get_department!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_department!(%Scope{} = scope, id) do
    Repo.get_by!(Department, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a department.

  ## Examples

      iex> create_department(scope, %{field: value})
      {:ok, %Department{}}

      iex> create_department(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_department(%Scope{} = scope, attrs) do
    with {:ok, department = %Department{}} <-
           %Department{}
           |> Department.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_department(scope, {:created, department})
      {:ok, department}
    end
  end

  @doc """
  Updates a department.

  ## Examples

      iex> update_department(scope, department, %{field: new_value})
      {:ok, %Department{}}

      iex> update_department(scope, department, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_department(%Scope{} = scope, %Department{} = department, attrs) do
    true = department.user_id == scope.user.id

    with {:ok, department = %Department{}} <-
           department
           |> Department.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_department(scope, {:updated, department})
      {:ok, department}
    end
  end

  @doc """
  Deletes a department.

  ## Examples

      iex> delete_department(scope, department)
      {:ok, %Department{}}

      iex> delete_department(scope, department)
      {:error, %Ecto.Changeset{}}

  """
  def delete_department(%Scope{} = scope, %Department{} = department) do
    true = department.user_id == scope.user.id

    with {:ok, department = %Department{}} <-
           Repo.delete(department) do
      broadcast_department(scope, {:deleted, department})
      {:ok, department}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking department changes.

  ## Examples

      iex> change_department(scope, department)
      %Ecto.Changeset{data: %Department{}}

  """
  def change_department(%Scope{} = scope, %Department{} = department, attrs \\ %{}) do
    true = department.user_id == scope.user.id

    Department.changeset(department, attrs, scope)
  end

  alias TrialApp.Organizations.Team
  alias TrialApp.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any team changes.

  The broadcasted messages match the pattern:

    * {:created, %Team{}}
    * {:updated, %Team{}}
    * {:deleted, %Team{}}

  """
  def subscribe_teams(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(TrialApp.PubSub, "user:#{key}:teams")
  end

  defp broadcast_team(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(TrialApp.PubSub, "user:#{key}:teams", message)
  end

  @doc """
  Returns the list of teams.

  ## Examples

      iex> list_teams(scope)
      [%Team{}, ...]

  """
  def list_teams(%Scope{} = scope) do
    Repo.all_by(Team, user_id: scope.user.id)
  end

  @doc """
  Gets a single team.

  Raises `Ecto.NoResultsError` if the Team does not exist.

  ## Examples

      iex> get_team!(scope, 123)
      %Team{}

      iex> get_team!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_team!(%Scope{} = scope, id) do
    Repo.get_by!(Team, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a team.

  ## Examples

      iex> create_team(scope, %{field: value})
      {:ok, %Team{}}

      iex> create_team(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_team(%Scope{} = scope, attrs) do
    with {:ok, team = %Team{}} <-
           %Team{}
           |> Team.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_team(scope, {:created, team})
      {:ok, team}
    end
  end

  @doc """
  Updates a team.

  ## Examples

      iex> update_team(scope, team, %{field: new_value})
      {:ok, %Team{}}

      iex> update_team(scope, team, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_team(%Scope{} = scope, %Team{} = team, attrs) do
    true = team.user_id == scope.user.id

    with {:ok, team = %Team{}} <-
           team
           |> Team.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_team(scope, {:updated, team})
      {:ok, team}
    end
  end

  @doc """
  Deletes a team.

  ## Examples

      iex> delete_team(scope, team)
      {:ok, %Team{}}

      iex> delete_team(scope, team)
      {:error, %Ecto.Changeset{}}

  """
  def delete_team(%Scope{} = scope, %Team{} = team) do
    true = team.user_id == scope.user.id

    with {:ok, team = %Team{}} <-
           Repo.delete(team) do
      broadcast_team(scope, {:deleted, team})
      {:ok, team}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.

  ## Examples

      iex> change_team(scope, team)
      %Ecto.Changeset{data: %Team{}}

  """
  def change_team(%Scope{} = scope, %Team{} = team, attrs \\ %{}) do
    true = team.user_id == scope.user.id

    Team.changeset(team, attrs, scope)
  end

  alias TrialApp.Organizations.Employee
  alias TrialApp.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any employee changes.

  The broadcasted messages match the pattern:

    * {:created, %Employee{}}
    * {:updated, %Employee{}}
    * {:deleted, %Employee{}}

  """
  def subscribe_employees(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(TrialApp.PubSub, "user:#{key}:employees")
  end

  defp broadcast_employee(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(TrialApp.PubSub, "user:#{key}:employees", message)
  end

  @doc """
  Returns the list of employees.

  ## Examples

      iex> list_employees(scope)
      [%Employee{}, ...]

  """
  def list_employees(%Scope{} = scope) do
    Repo.all_by(Employee, user_id: scope.user.id)
  end

  @doc """
  Gets a single employee.

  Raises `Ecto.NoResultsError` if the Employee does not exist.

  ## Examples

      iex> get_employee!(scope, 123)
      %Employee{}

      iex> get_employee!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_employee!(%Scope{} = scope, id) do
    Repo.get_by!(Employee, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a employee.

  ## Examples

      iex> create_employee(scope, %{field: value})
      {:ok, %Employee{}}

      iex> create_employee(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_employee(%Scope{} = scope, attrs) do
    with {:ok, employee = %Employee{}} <-
           %Employee{}
           |> Employee.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_employee(scope, {:created, employee})
      {:ok, employee}
    end
  end

  @doc """
  Updates a employee.

  ## Examples

      iex> update_employee(scope, employee, %{field: new_value})
      {:ok, %Employee{}}

      iex> update_employee(scope, employee, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_employee(%Scope{} = scope, %Employee{} = employee, attrs) do
    true = employee.user_id == scope.user.id

    with {:ok, employee = %Employee{}} <-
           employee
           |> Employee.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_employee(scope, {:updated, employee})
      {:ok, employee}
    end
  end

  @doc """
  Deletes a employee.

  ## Examples

      iex> delete_employee(scope, employee)
      {:ok, %Employee{}}

      iex> delete_employee(scope, employee)
      {:error, %Ecto.Changeset{}}

  """
  def delete_employee(%Scope{} = scope, %Employee{} = employee) do
    true = employee.user_id == scope.user.id

    with {:ok, employee = %Employee{}} <-
           Repo.delete(employee) do
      broadcast_employee(scope, {:deleted, employee})
      {:ok, employee}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking employee changes.

  ## Examples

      iex> change_employee(scope, employee)
      %Ecto.Changeset{data: %Employee{}}

  """
  def change_employee(%Scope{} = scope, %Employee{} = employee, attrs \\ %{}) do
    true = employee.user_id == scope.user.id

    Employee.changeset(employee, attrs, scope)
  end

  alias TrialApp.Organizations.Position
  alias TrialApp.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any position changes.

  The broadcasted messages match the pattern:

    * {:created, %Position{}}
    * {:updated, %Position{}}
    * {:deleted, %Position{}}

  """
  def subscribe_positions(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(TrialApp.PubSub, "user:#{key}:positions")
  end

  defp broadcast_position(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(TrialApp.PubSub, "user:#{key}:positions", message)
  end

  @doc """
  Returns the list of positions.

  ## Examples

      iex> list_positions(scope)
      [%Position{}, ...]

  """
  def list_positions(%Scope{} = scope) do
    Repo.all_by(Position, user_id: scope.user.id)
  end

  @doc """
  Gets a single position.

  Raises `Ecto.NoResultsError` if the Position does not exist.

  ## Examples

      iex> get_position!(scope, 123)
      %Position{}

      iex> get_position!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_position!(%Scope{} = scope, id) do
    Repo.get_by!(Position, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a position.

  ## Examples

      iex> create_position(scope, %{field: value})
      {:ok, %Position{}}

      iex> create_position(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_position(%Scope{} = scope, attrs) do
    with {:ok, position = %Position{}} <-
           %Position{}
           |> Position.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_position(scope, {:created, position})
      {:ok, position}
    end
  end

  @doc """
  Updates a position.

  ## Examples

      iex> update_position(scope, position, %{field: new_value})
      {:ok, %Position{}}

      iex> update_position(scope, position, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_position(%Scope{} = scope, %Position{} = position, attrs) do
    true = position.user_id == scope.user.id

    with {:ok, position = %Position{}} <-
           position
           |> Position.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_position(scope, {:updated, position})
      {:ok, position}
    end
  end

  @doc """
  Deletes a position.

  ## Examples

      iex> delete_position(scope, position)
      {:ok, %Position{}}

      iex> delete_position(scope, position)
      {:error, %Ecto.Changeset{}}

  """
  def delete_position(%Scope{} = scope, %Position{} = position) do
    true = position.user_id == scope.user.id

    with {:ok, position = %Position{}} <-
           Repo.delete(position) do
      broadcast_position(scope, {:deleted, position})
      {:ok, position}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking position changes.

  ## Examples

      iex> change_position(scope, position)
      %Ecto.Changeset{data: %Position{}}

  """
  def change_position(%Scope{} = scope, %Position{} = position, attrs \\ %{}) do
    true = position.user_id == scope.user.id

    Position.changeset(position, attrs, scope)
  end
end
