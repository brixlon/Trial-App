defmodule TrialApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :status, :string, default: "pending"

    # Support both RBAC and simple role arrays for flexibility
    field :roles, {:array, :string}, default: []
    field :active_role, :string

    field :first_name, :string
    field :last_name, :string
    field :phone_number, :string

    field :must_change_password, :boolean, default: false
    field :password_changed_at, :utc_datetime

    # RBAC: User belongs to a Role (for full RBAC system with permissions)
    belongs_to :role, TrialApp.Accounts.Role

    has_many :employees, TrialApp.Orgs.Employee
    has_many :teams, through: [:employees, :team]
    has_many :organizations, through: [:employees, :team, :organization]
    has_many :departments, through: [:employees, :team, :department]

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :password, :role_id])
    |> validate_required([:email, :username, :password, :role_id])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 8, max: 72)
    |> validate_confirmation(:password, message: "does not match password")
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> foreign_key_constraint(:role_id)
    |> put_hashed_password(opts)
    |> change(status: "pending")
  end

  defp put_hashed_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for updating user profile information.
  Now supports both single role and multiple roles.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :role_id, :status])
    |> validate_required([:email, :username])
    |> validate_inclusion(:status, ["pending", "active", "suspended"])
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> foreign_key_constraint(:role_id)
  end

  @doc """
  A user changeset for admin to update all user details including assignments.
  """
  def admin_update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :role_id, :roles, :status])
    |> validate_required([:email, :username])
    |> validate_inclusion(:status, ["pending", "active", "suspended"])
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> foreign_key_constraint(:role_id)
    |> validate_roles()
  end

  defp validate_roles(changeset) do
    case get_change(changeset, :roles) do
      nil ->
        changeset

      roles when is_list(roles) ->
        valid_roles = ["attachee", "supervisor", "admin"]

        if Enum.all?(roles, &(&1 in valid_roles)) do
          changeset
        else
          add_error(changeset, :roles, "contains invalid roles")
        end

      _ ->
        add_error(changeset, :roles, "must be a list")
    end
  end

  @doc """
  A user changeset for admin to create a user from contact information.
  Generates username and password automatically.
  """
  def admin_create_changeset(user, attrs) do
    status = Map.get(attrs, "status") || Map.get(attrs, :status) || "pending"
    _role_id = Map.get(attrs, "role_id") || Map.get(attrs, :role_id)

    user
    |> cast(attrs, [:email, :first_name, :last_name, :phone_number, :role_id, :status])
    |> validate_required([:email, :first_name, :last_name, :phone_number])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> validate_inclusion(:status, ["pending", "active", "suspended"])
    |> unique_constraint(:email)
    |> foreign_key_constraint(:role_id)
    |> generate_username_from_name()
    |> generate_default_password()
    |> put_hashed_password([])
    |> change(status: status)
  end

  defp generate_username_from_name(changeset) do
    first_name = get_change(changeset, :first_name) || get_field(changeset, :first_name)
    last_name = get_change(changeset, :last_name) || get_field(changeset, :last_name)
    email = get_change(changeset, :email) || get_field(changeset, :email)

    username =
      if first_name && last_name do
        base_username =
          "#{String.downcase(first_name)}.#{String.downcase(last_name)}"
          |> String.replace(~r/[^a-z0-9_]/, "_")
          # Leave room for suffix
          |> String.slice(0, 20)

        random_suffix = :rand.uniform(9999)
        "#{base_username}#{random_suffix}"
      else
        email_prefix =
          email
          |> String.split("@")
          |> List.first()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9_]/, "_")
          # Leave room for suffix
          |> String.slice(0, 20)

        random_suffix = :rand.uniform(9999)
        "#{email_prefix}#{random_suffix}"
      end

    changeset
    |> put_change(:username, username)
  end

  defp generate_default_password(changeset) do
    password =
      :crypto.strong_rand_bytes(12)
      |> Base.encode64()
      |> String.slice(0, 12)

    changeset
    |> put_change(:password, password)
  end

  @doc """
  A user changeset for updating user with team assignments.
  """
  def assignment_changeset(user, attrs) do
    user
    |> cast(attrs, [:role_id, :status])
    |> validate_inclusion(:status, ["pending", "active", "suspended"])
    |> foreign_key_constraint(:role_id)
  end

  @doc """
  A user changeset for registering or changing the email.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, TrialApp.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for registering or changing the username.
  """
  def username_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username])
    |> validate_username(opts)
  end

  defp validate_username(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:username])
      |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
        message: "can only contain letters, numbers, and underscores"
      )
      |> validate_length(:username, min: 3, max: 30)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:username, TrialApp.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/,
      message: "must contain at least one lowercase letter"
    )
    |> validate_format(:password, ~r/[A-Z]/,
      message: "must contain at least one uppercase letter"
    )
    |> validate_format(:password, ~r/[0-9]/, message: "must contain at least one number")
    |> validate_format(:password, ~r/[!@#$%^&*(),.?":{}|<>]/,
      message: "must contain at least one special character"
    )
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      # ✅ track password updates
      |> put_change(:password_changed_at, DateTime.utc_now() |> DateTime.truncate(:second))
      # ✅ reset flag after password change
      |> change(%{must_change_password: false})
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now()
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.
  """
  def valid_password?(%TrialApp.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Returns a user with all relationships preloaded for admin dashboard.
  """
  def with_preloads(user) do
    TrialApp.Repo.preload(user,
      employees: [:team, :department, :organization],
      teams: [:organization, :department],
      organizations: [],
      departments: []
    )
  end

  @doc """
  Returns a user with minimal preloads for performance.
  """
  def with_basic_preloads(user) do
    TrialApp.Repo.preload(user, [:employees])
  end
end
