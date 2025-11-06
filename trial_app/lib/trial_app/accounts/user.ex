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

    # NEW: Multiple roles support
    field :roles, {:array, :string}, default: ["attachee"]
    field :active_role, :string, default: "attachee"

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
    user
    |> cast(attrs, [:email, :username, :roles, :status, :must_change_password, :active_role])
    |> validate_required([:email, :username, :roles, :status])
    |> validate_roles()
    |> validate_active_role()
    |> validate_inclusion(:status, @statuses)
    |> validate_email()
    |> validate_username()
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end

  # ————————————————————————————
  # ROLE SWITCHING
  # ————————————————————————————
  def switch_role_changeset(user, new_role) do
    user
    |> change(active_role: new_role)
    |> validate_active_role()
  end

  # ————————————————————————————
  # PASSWORD CHANGE
  # ————————————————————————————
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> put_hashed_password(opts)
  end

  # ————————————————————————————
  # VALIDATIONS
  # ————————————————————————————
  defp validate_roles(changeset) do
    changeset
    |> validate_required([:roles])
    |> validate_length(:roles, min: 1, message: "must have at least one role")
    |> validate_change(:roles, fn :roles, roles ->
      invalid_roles = Enum.reject(roles, &(&1 in @all_roles))
      if Enum.empty?(invalid_roles), do: [], else: [roles: "invalid roles: #{Enum.join(invalid_roles, ", ")}"]
    end)
  end

  defp validate_active_role(changeset) do
    validate_change(changeset, :active_role, fn :active_role, active_role ->
      roles = get_field(changeset, :roles) || []
      cond do
        active_role not in @all_roles -> [active_role: "is not a valid role"]
        active_role not in roles -> [active_role: "must be one of your assigned roles"]
        true -> []
      end
    end)
  end

  defp put_default_active_role(changeset) do
    case get_change(changeset, :roles) do
      nil -> changeset
      [] -> changeset
      [first | _] -> put_change(changeset, :active_role, first)
    end
  end

  defp validate_email(changeset, opts \\ []) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must be valid")
    |> validate_length(:email, max: 160)
    |> then(fn cs ->
      if Keyword.get(opts, :validate_unique, true) do
        unsafe_validate_unique(cs, :email, TrialApp.Repo) |> unique_constraint(:email)
      else
        cs
      end
    end)
  end

  defp validate_username(changeset, opts \\ []) do
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
