defmodule TrialApp.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `TrialApp.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  The scope now includes role-based authorization with support for multiple
  roles per user and an active role that determines the current context.
  """

  alias TrialApp.Accounts.User

  defstruct [
    :user,
    :active_role,
    roles: [],
    is_admin: false,
    is_supervisor: false,
    is_attachee: false
  ]

  @doc """
  Creates a scope for the given user.

  ## Options
  - `:active_role` - The role to activate for this scope (defaults to user's active_role)

  Returns nil if no user is given.
  """
  def for_user(user, opts \\ [])

  def for_user(%User{} = user, opts) do
    active_role = Keyword.get(opts, :active_role, user.active_role)

    # Ensure the active role is valid for this user
    active_role =
      if active_role in user.roles do
        active_role
      else
        List.first(user.roles) || "attachee"
      end

    %__MODULE__{
      user: user,
      active_role: active_role,
      roles: user.roles || [],
      is_admin: "admin" in (user.roles || []),
      is_supervisor: "supervisor" in (user.roles || []),
      is_attachee: "attachee" in (user.roles || [])
    }
  end

  def for_user(nil, _opts), do: %__MODULE__{}

  @doc """
  Checks if the scope has the given role.
  """
  def has_role?(%__MODULE__{roles: roles}, role) when is_list(roles) do
    role in roles
  end
  def has_role?(_, _), do: false

  @doc """
  Checks if the scope has any of the given roles.
  """
  def has_any_role?(%__MODULE__{roles: roles}, check_roles) when is_list(roles) and is_list(check_roles) do
    Enum.any?(check_roles, &(&1 in roles))
  end
  def has_any_role?(_, _), do: false

  @doc """
  Checks if the scope's active role matches the given role.
  """
  def active_role?(%__MODULE__{active_role: active}, role) do
    active == role
  end

  @doc """
  Returns all available roles for this scope.
  """
  def available_roles(%__MODULE__{roles: roles}), do: roles

  @doc """
  Returns the human-readable name for a role.
  """
  def role_display_name("admin"), do: "Administrator"
  def role_display_name("supervisor"), do: "Supervisor"
  def role_display_name("attachee"), do: "Attachée"
  def role_display_name(role), do: role |> String.capitalize()

  @doc """
  Returns the dashboard path for a given role.
  """
  def role_dashboard_path("admin"), do: "/admin/dashboard"
  def role_dashboard_path("supervisor"), do: "/supervisor/dashboard"
  def role_dashboard_path("attachee"), do: "/attachee/dashboard"
  def role_dashboard_path(_), do: "/dashboard"
end
