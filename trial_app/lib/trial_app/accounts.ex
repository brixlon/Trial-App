defmodule TrialApp.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Accounts.{User, UserToken, UserNotifier}
  alias TrialApp.Orgs.{Department, Team, Employee}

  ## Database getters

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by username or email and password.
  """
  def get_user_by_username_or_email_and_password(username_or_email, password)
      when is_binary(username_or_email) and is_binary(password) do
    # Check if it looks like an email (contains @)
    user = if String.contains?(username_or_email, "@") do
      Repo.get_by(User, email: username_or_email)
    else
      Repo.get_by(User, username: username_or_email)
    end

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user with all assignments preloaded.
  """
  def get_user_with_assignments!(id) do
    User
    |> where(id: ^id)
    |> preload([employees: [:organization, :department, :team]])
    |> Repo.one!()
  end

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(User)
    |> Repo.preload([employees: [:organization, :department, :team]])
  end

  @doc """
  Lists users by status.
  """
  def list_users_by_status(status) when is_binary(status) do
    User
    |> where([u], u.status == ^status)
    |> Repo.all()
    |> Repo.preload([employees: [:organization, :department, :team]])
  end

  @doc """
  Lists users by role.
  """
  # Around line 80-90:
def update_user(user, attrs) do
  user
  |> User.admin_update_changeset(attrs)
  |> Repo.update()
end

def list_users_with_assignments do
  User
  |> preload(employees: [:team, :department, :organization])
  |> Repo.all()
end
  # Add this function around line 80:
def update_user(user, attrs) do
  user
  |> User.admin_update_changeset(attrs)
  |> Repo.update()
end
  def list_users_by_role(role) when is_binary(role) do
    User
    |> where([u], u.role == ^role)
    |> Repo.all()
    |> Repo.preload([employees: [:organization, :department, :team]])
  end

  @doc """
  Lists users pending assignment/approval.
  """
  def list_pending_assignment_users do
    User
    |> where([u], u.status == "pending")
    |> Repo.all()
    |> Repo.preload([employees: [:organization, :department, :team]])
  end

  @doc """
  Updates a user's status.
  """
  def update_user_status(user, status) do
    user
    |> Ecto.Changeset.change(%{status: status})
    |> Repo.update()
  end

  @doc """
  Updates a user's role.
  """
  def update_user_role(user, role) do
    user
    |> Ecto.Changeset.change(%{role: role})
    |> Repo.update()
  end

  @doc """
  Updates a user with assignments and team assignments.
  """
  def update_user_with_assignments(user, params, team_ids) do
  Repo.transaction(fn ->
    # Update user basic info - USE THE CORRECT CHANGESET
    user_changeset = User.admin_update_changeset(user, params)

    case Repo.update(user_changeset) do
      {:ok, updated_user} ->
        IO.inspect("User updated successfully")
        IO.inspect(updated_user.updated_at, label: "NEW UPDATED_AT TIMESTAMP")

        # Handle employee records for teams
        if Enum.any?(team_ids) do
          # Delete existing employee records for this user
          Repo.delete_all(from(e in Employee, where: e.user_id == ^user.id))

          # Create new employee records for each selected team
          Enum.each(team_ids, fn team_id ->
            team = Repo.get!(Team, team_id) |> Repo.preload(department: [:organization])

            employee_attrs = %{
              user_id: updated_user.id,
              name: updated_user.username || updated_user.email,
              email: updated_user.email,
              team_id: team_id,
              department_id: team.department_id,
              organization_id: team.department.organization_id,
              role: updated_user.role || "user",
              position: "Employee",
              is_active: true,
              status: "active"
            }

            %Employee{}
            |> Employee.changeset(employee_attrs)
            |> Repo.insert!()
          end)
        else
          # If no teams selected, remove all employee records
          Repo.delete_all(from(e in Employee, where: e.user_id == ^user.id))
        end

        updated_user

      {:error, changeset} ->
        IO.inspect("User update failed")
        IO.inspect(changeset.errors, label: "UPDATE ERRORS")
        Repo.rollback(changeset)
    end
  end)
end

  ## User registration

  @doc """
  Registers a user.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.
  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.
  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.
  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Delivers the update email instructions to the given user.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Department functions

  @doc """
  Lists all departments.
  """
  def list_departments do
    Repo.all(Department)
  end

  @doc """
  Gets a single department.

  Raises `Ecto.NoResultsError` if the Department does not exist.
  """
  def get_department!(id), do: Repo.get!(Department, id)

  @doc """
  Creates a department.
  """
  def create_department(attrs \\ %{}) do
    %Department{}
    |> Department.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a department.
  """
  def update_department(%Department{} = department, attrs) do
    department
    |> Department.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a department.
  """
  def delete_department(%Department{} = department) do
    Repo.delete(department)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking department changes.
  """
  def change_department(%Department{} = department, attrs \\ %{}) do
    Department.changeset(department, attrs)
  end

  ## Team functions

  @doc """
  Lists all teams.
  """
  def list_teams do
    Repo.all(Team)
    |> Repo.preload([:department])
  end

  @doc """
  Gets a single team.

  Raises `Ecto.NoResultsError` if the Team does not exist.
  """
  def get_team!(id), do: Repo.get!(Team, id)

  @doc """
  Gets a team with all preloads.
  """
  def get_team_with_preloads!(id) do
    Team
    |> where(id: ^id)
    |> preload([department: [:organization], employees: [:user]])
    |> Repo.one!()
  end

  @doc """
  Creates a team.
  """
  def create_team(attrs \\ %{}) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a team.
  """
  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team.
  """
  def delete_team(%Team{} = team) do
    Repo.delete(team)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.
  """
  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end

  ## Employee functions

  @doc """
  Gets an employee by user ID.
  """
  def get_employee_by_user_id(user_id) do
    Repo.get_by(Employee, user_id: user_id)
    |> Repo.preload([:department, :team, :organization])
  end

  @doc """
  Gets all employees for a user (for multiple team support).
  """
  def get_employees_by_user_id(user_id) do
    Employee
    |> where(user_id: ^user_id)
    |> Repo.all()
    |> Repo.preload([:department, :team, :organization])
  end

  @doc """
  Creates an employee.
  """
  def create_employee(attrs \\ %{}) do
    %Employee{}
    |> Employee.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an employee.
  """
  def update_employee(%Employee{} = employee, attrs) do
    employee
    |> Employee.changeset(attrs)
    |> Repo.update()
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
