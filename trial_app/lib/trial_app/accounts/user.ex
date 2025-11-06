defmodule TrialApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @all_roles ~w(attachee supervisor admin)
  @statuses ~w(pending active suspended)

  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :status, :string, default: "pending"
    field :role, :string, default: "user"
    field :first_name, :string
    field :last_name, :string
    field :phone_number, :string

    # DEPRECATED: Keep for backwards compatibility
    field :role, :string, virtual: true

    # Password reset / force change
    field :must_change_password, :boolean, default: false
    field :password_changed_at, :utc_datetime

    # Relationships
    has_many :employees, TrialApp.Orgs.Employee
    has_many :teams, through: [:employees, :team]
    has_many :organizations, through: [:employees, :team, :organization]
    has_many :departments, through: [:employees, :team, :department]

    timestamps(type: :utc_datetime)
  end

  # ————————————————————————————
  # ROLE HELPERS
  # ————————————————————————————
  def has_role?(%__MODULE__{roles: roles}, role) when is_list(roles), do: role in roles
  def has_role?(_, _), do: false

  def has_any_role?(%__MODULE__{roles: roles}, check_roles) when is_list(roles) and is_list(check_roles),
    do: Enum.any?(check_roles, &(&1 in roles))
  def has_any_role?(_, _), do: false

  def is_admin?(%__MODULE__{} = user), do: has_role?(user, "admin")
  def is_supervisor?(%__MODULE__{} = user), do: has_role?(user, "supervisor")
  def is_attachee?(%__MODULE__{} = user), do: has_role?(user, "attachee")

  def available_roles(%__MODULE__{roles: roles}) when is_list(roles), do: roles
  def available_roles(_), do: []

  def all_roles, do: @all_roles

  # ————————————————————————————
  # REGISTRATION
  # ————————————————————————————
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :password, :roles])
    |> validate_required([:email, :username, :password])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 8, max: 72)
    |> validate_confirmation(:password, message: "does not match password")
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> validate_roles()
    |> put_default_active_role()
    |> put_hashed_password(opts)
    |> change(status: "pending")
  end

  # ————————————————————————————
  # PROFILE UPDATE (User)
  # ————————————————————————————
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username])
    |> validate_required([:email, :username])
    |> validate_email()
    |> validate_username()
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end

  # ————————————————————————————
  # ADMIN UPDATE (Full control)
  # ————————————————————————————
  def admin_update_changeset(user, attrs) do
    # Delegate to profile_changeset to avoid code duplication
    profile_changeset(user, attrs)
  end

  @doc """
  A user changeset for admin to create a user from contact information.
  Generates username and password automatically.
  """
  def admin_create_changeset(user, attrs) do
    status = Map.get(attrs, "status") || Map.get(attrs, :status) || "pending"
    role = Map.get(attrs, "role") || Map.get(attrs, :role) || "employee"

    user
    |> cast(attrs, [:email, :first_name, :last_name, :phone_number, :role, :status])
    |> validate_required([:email, :first_name, :last_name, :phone_number])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> validate_inclusion(:role, ["admin", "manager", "employee"])
    |> validate_inclusion(:status, ["pending", "active", "suspended"])
    |> unique_constraint(:email)
    |> generate_username_from_name()
    |> generate_default_password()
    |> put_hashed_password([])
    |> change(status: status, role: role)
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
          |> String.slice(0, 20)  # Leave room for suffix

        # Generate a unique username by appending a random number
        # The unique_constraint will handle conflicts if they occur
        random_suffix = :rand.uniform(9999)
        "#{base_username}#{random_suffix}"
      else
        # Fallback to email prefix with random suffix
        email_prefix =
          email
          |> String.split("@")
          |> List.first()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9_]/, "_")
          |> String.slice(0, 20)  # Leave room for suffix

        random_suffix = :rand.uniform(9999)
        "#{email_prefix}#{random_suffix}"
      end

    changeset
    |> put_change(:username, username)
  end

  defp generate_default_password(changeset) do
    # Generate a random password
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
    |> cast(attrs, [:role, :status])
    |> validate_required([:role])
    |> validate_inclusion(:role, ["admin", "manager", "employee"])
    |> validate_inclusion(:status, ["pending", "active", "suspended"])
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
    |> validate_required([:username])
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "only letters, numbers, underscores")
    |> validate_length(:username, min: 3, max: 30)
    |> then(fn cs ->
      if Keyword.get(opts, :validate_unique, true) do
        unsafe_validate_unique(cs, :username, TrialApp.Repo) |> unique_constraint(:username)
      else
        cs
      end
    end)
  end

  # ————————————————————————————
  # PASSWORD HASHING
  # ————————————————————————————
  defp put_hashed_password(changeset, opts) do
    hash? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> put_change(:password_changed_at, DateTime.utc_now())
      |> put_change(:must_change_password, false)
      |> delete_change(:password)
    else
      changeset
    end
  end

  # ————————————————————————————
  # CONFIRMATION
  # ————————————————————————————
  def confirm_changeset(user) do
    change(user, confirmed_at: DateTime.utc_now())
  end

  # ————————————————————————————
  # PASSWORD VERIFICATION
  # ————————————————————————————
  def valid_password?(%__MODULE__{hashed_password: hashed}, password)
      when is_binary(hashed) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  # ————————————————————————————
  # PRELOAD HELPERS
  # ————————————————————————————
  def with_preloads(user) do
    TrialApp.Repo.preload(user,
      employees: [:team, :department, :organization],
      teams: [:organization, :department],
      organizations: [],
      departments: []
    )
  end
# lib/trial_app/accounts/user.ex
def assignment_changeset(user, attrs) do
  user
  |> cast(attrs, [:status, :must_change_password])
  |> validate_required([:status])
end
  def with_basic_preloads(user) do
    TrialApp.Repo.preload(user, [:employees])
  end
end
