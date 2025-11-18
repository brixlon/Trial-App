defmodule TrialApp.Accounts do
  @moduledoc """
  The Accounts context.
  """
  import Ecto.Query, warn: false
  alias TrialApp.Repo
  alias TrialApp.Accounts.{User, UserToken, UserNotifier}
  alias TrialApp.Orgs.{Department, Team, Employee}
  alias TrialApp.Eams

  ## Database getters

  @doc """
  Gets a user by email.
  """
def get_user_by_email(email) when is_binary(email) do
  Repo.get_by(User, email: email)
end


def get_user_by_email_and_password(email, password)
    when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: String.downcase(email))
    if user && User.valid_password?(user, password) do
      user
    else
      Bcrypt.no_user_verify()
      nil
    end
  end

  @doc """
  Gets a user by username or email and password.
  Case-insensitive email, constant-time verification.
  """
  def get_user_by_username_or_email_and_password(username_or_email, password)
      when is_binary(username_or_email) and is_binary(password) do
    field = if String.contains?(username_or_email, "@"), do: :email, else: :username
    lookup_value = if field == :email, do: String.downcase(username_or_email), else: username_or_email
    user = Repo.get_by(User, [{field, lookup_value}])
    if user && User.valid_password?(user, password) do
      user
    else
      Bcrypt.no_user_verify()
      nil
    end
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user with all assignments preloaded.
  """
  def get_user_with_assignments!(id) do
    User
    |> where(id: ^id)
    |> preload(employees: [:organization, :department, :team])
    |> Repo.one!()
  end

  @doc """
  Lists all users.
  """
  def list_users do
    User
    |> preload(employees: [:organization, :department, :team])
    |> Repo.all()
  end

  @doc """
  Lists users by status.
  """
  def list_users_by_status(status) when is_binary(status) do
    User
    |> where([u], u.status == ^status)
    |> preload(employees: [:organization, :department, :team])
    |> Repo.all()
  end

  @doc """
  Updates a user.
  """
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

  def list_users_by_role(role) when is_binary(role) do
    User
    |> where([u], u.role == ^role)
    |> preload(employees: [:organization, :department, :team])
    |> Repo.all()
  end

  @doc """
  Lists users pending assignment/approval.
  """
  def list_pending_assignment_users do
    User
    |> where([u], u.status == "pending")
    |> preload(employees: [:organization, :department, :team])
    |> Repo.all()
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
  def update_user_with_assignments(user, params, team_ids, opts \\ %{}) do
    Repo.transaction(fn ->
      user_changeset = User.admin_update_changeset(user, params)

      case Repo.update(user_changeset) do
        {:ok, updated_user} ->
          if Enum.any?(team_ids) do
            Repo.delete_all(from(e in Employee, where: e.user_id == ^updated_user.id))

            Enum.each(team_ids, fn team_id ->
              team = Repo.get!(Team, team_id) |> Repo.preload(department: [:organization])
              employee_attrs = %{
                user_id: updated_user.id,
                name: updated_user.username || updated_user.email,
                email: updated_user.email,
                team_id: team_id,
                department_id: team.department_id,
                organization_id: team.department.organization_id,
                role: normalize_employee_role(updated_user.role),
                position: "Employee",
                is_active: true,
                status: "active"
              }

              %Employee{}
              |> Employee.changeset(employee_attrs)
              |> Repo.insert!()

              # Optionally create Attachee
              if Map.get(opts, :attachee?) do
                dates = Map.get(opts, :attachee_dates, %{})
                starts_on = blank_to_nil(Map.get(dates, "starts_on"))
                ends_on = blank_to_nil(Map.get(dates, "ends_on"))

                attachee_attrs = %{
                  user_id: updated_user.id,
                  organization_id: team.department.organization_id,
                  department_id: team.department_id,
                  status: "active",
                  starts_on: starts_on,
                  ends_on: ends_on
                }

                _ = Eams.create_attachee(attachee_attrs)
              end
            end)

            {:ok, _} =
              updated_user
              |> Ecto.Changeset.change(%{status: "active"})
              |> Repo.update()
          else
            Repo.delete_all(from(e in Employee, where: e.user_id == ^updated_user.id))
          end

          updated_user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end






  defp blank_to_nil(""), do: nil
  defp blank_to_nil(val), do: val

  defp normalize_employee_role(user_role) do
    case user_role do
      "admin" -> "admin"
      "manager" -> "manager"
      "lead" -> "lead"
      "employee" -> "employee"
      _ -> "member"
    end
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
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

  Repo.transaction(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _} <- Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
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
  Gets the user with the given signed session token.
  Returns {user, token_inserted_at} or nil.
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
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise "magic link log in is not allowed for unconfirmed users with a password set!"

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
  Delivers the update email instructions.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")
    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions.
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

  ## Department / Team / Employee

  @doc """
  Lists all departments.
  """
  def list_departments do
    Repo.all(Department)
  end

  def get_department!(id), do: Repo.get!(Department, id)

  def create_department(attrs \\ %{}) do
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

  def change_department(%Department{} = department, attrs \\ %{}) do
    Department.changeset(department, attrs)
  end

  def list_teams do
    Team
    |> preload([:department])
    |> Repo.all()
  end

  def get_team!(id), do: Repo.get!(Team, id)

  def get_team_with_preloads!(id) do
    Team
    |> where(id: ^id)
    |> preload(department: [:organization], employees: [:user])
    |> Repo.one!()
  end

  def create_team(attrs \\ %{}) do
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

  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end

  def get_employee_by_user_id(user_id) do
    Repo.get_by(Employee, user_id: user_id)
    |> Repo.preload([:department, :team, :organization])
  end

  def get_employees_by_user_id(user_id) do
    Employee
    |> where(user_id: ^user_id)
    |> preload([:department, :team, :organization])
    |> Repo.all()
  end

  def create_employee(attrs \\ %{}) do
    %Employee{}
    |> Employee.changeset(attrs)
    |> Repo.insert()
  end

  def update_employee(%Employee{} = employee, attrs) do
    employee
    |> Employee.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user from admin form (with first_name, last_name, phone_number).
  Generates username and password automatically.
  """
  def create_user(attrs) do
    %User{}
    |> User.admin_create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a user with team assignments.
  """
  def create_user_with_assignments(user_params, team_ids) do
    Repo.transaction(fn ->
      user_changeset = User.registration_changeset(%User{}, user_params)

      case Repo.insert(user_changeset) do
        {:ok, new_user} ->
          if Enum.any?(team_ids) do
            Enum.each(team_ids, fn team_id ->
              team = Repo.get!(Team, team_id) |> Repo.preload(department: [:organization])
              employee_attrs = %{
                user_id: new_user.id,
                name: new_user.username || new_user.email,
                email: new_user.email,
                team_id: team_id,
                department_id: team.department_id,
                organization_id: team.department.organization_id,
                role: normalize_employee_role(new_user.role),
                position: "Employee",
                is_active: true,
                status: "active"
              }

              %Employee{}
              |> Employee.changeset(employee_attrs)
              |> Repo.insert!()
            end)
          end

          new_user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Checks if the user must change their password.
  """
  def must_change_password?(%User{must_change_password: true}), do: true
  def must_change_password?(%User{must_change_password: false}), do: false
  def must_change_password?(_), do: false

  ## ROLE SWITCHING FUNCTIONS

  @doc """
  Switches the user's active role.
  Only allows switching to roles the user actually has.
  """
  def switch_user_role(user, new_role) do
    available_roles = get_user_roles(user)
    if new_role in available_roles do
      user
      |> Ecto.Changeset.change(%{active_role: new_role})
      |> Repo.update()
    else
      {:error, :unauthorized_role}
    end
  end

  @doc """
  Gets all roles available to a user.
  Returns the roles array if populated, otherwise returns single role as list.
  """
def get_user_roles(%User{roles: roles, role: single_role}) do
  array_roles = if is_list(roles), do: roles || [], else: []
  single_role_list = if is_binary(single_role) and single_role != "", do: [single_role], else: []
  (array_roles ++ single_role_list) |> Enum.uniq() |> Enum.reject(&is_nil/1)
end

  @doc """
  Gets the user's active role.
  Falls back to first available role if active_role is not set.
  """
  def get_active_role(%User{active_role: active_role} = _user) when not is_nil(active_role) do
    active_role
  end

  def get_active_role(%User{} = user) do
    user
    |> get_user_roles()
    |> List.first()
  end

  @doc """
  Checks if user has a specific role.
  """
  def has_role?(%User{} = user, role) do
    role in get_user_roles(user)
  end

  @doc """
  Adds a role to a user's roles array.
  """
  def add_role_to_user(%User{} = user, new_role) do
    current_roles = user.roles || []
    if new_role not in current_roles do
      updated_roles = [new_role | current_roles] |> Enum.uniq()
      user
      |> Ecto.Changeset.change(%{roles: updated_roles})
      |> Repo.update()
    else
      {:ok, user}
    end
  end

  @doc """
  Removes a role from a user's roles array.
  """
  def remove_role_from_user(%User{} = user, role_to_remove) do
    updated_roles = (user.roles || []) |> Enum.reject(&(&1 == role_to_remove))

    changeset =
      user
      |> Ecto.Changeset.change(%{roles: updated_roles})

    changeset =
      if user.active_role == role_to_remove && Enum.any?(updated_roles) do
        Ecto.Changeset.put_change(changeset, :active_role, List.first(updated_roles))
      else
        changeset
      end

    Repo.update(changeset)
  end

  @doc """
  Ensures the user has an active_role set.
  Call this after login to initialize the active role if it's nil.
  This is CRITICAL for the sidebar to work correctly on first login.
  """
  def ensure_active_role(%User{active_role: nil} = user) do
    available_roles = get_user_roles(user)

    if Enum.any?(available_roles) do
      # Determine the appropriate default role based on priority
      default_role = determine_default_role(available_roles)

      IO.inspect(default_role, label: "Setting active_role for user #{user.id}")

      user
      |> Ecto.Changeset.change(%{active_role: default_role})
      |> Repo.update()
    else
      # No roles available - this shouldn't happen but handle gracefully
      {:ok, user}
    end
  end

  def ensure_active_role(%User{} = user) do
    # Active role already set
    {:ok, user}
  end

  # Helper to determine the best default role based on priority
  # Attachee gets priority since that's the most specific role
  defp determine_default_role(roles) do
    cond do
      "attachee" in roles -> "attachee"
      "supervisor" in roles -> "supervisor"
      "manager" in roles -> "manager"
      "admin" in roles -> "admin"
      "employee" in roles -> "employee"
      true -> List.first(roles)
    end
  end

  def generate_password_reset_token(%User{id: user_id}) do
    Phoenix.Token.sign(TrialAppWeb.Endpoint, "force_password_reset", user_id)
  end

  def generate_force_reset_token(user) do
    Phoenix.Token.sign(TrialAppWeb.Endpoint, "force_password_reset", user.id)
  end

  @doc """
  Verifies a force reset token and returns the user.
  """
  def verify_force_reset_token(token) do
    case Phoenix.Token.verify(TrialAppWeb.Endpoint, "force_password_reset", token, max_age: 86400) do
      {:ok, user_id} ->
        Repo.get(User, user_id)
      {:error, _} ->
        nil
    end
  end

  @doc """
  Deletes a user and associated data.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  # Private helpers
  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transaction(fn ->
      # Sanitize any datetime fields in the changeset to remove microseconds
      sanitized_changeset =
        changeset
        |> Ecto.Changeset.update_change(:password_changed_at, fn
          nil -> nil
          dt -> DateTime.truncate(dt, :second)
        end)
        |> Ecto.Changeset.update_change(:authenticated_at, fn
          nil -> nil
          dt -> DateTime.truncate(dt, :second)
        end)
        |> Ecto.Changeset.update_change(:confirmed_at, fn
          nil -> nil
          dt -> DateTime.truncate(dt, :second)
        end)

      with {:ok, user} <- Repo.update(sanitized_changeset) do
        tokens_to_expire =
          Repo.all(from(t in UserToken, where: t.user_id == ^user.id))

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))
        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
