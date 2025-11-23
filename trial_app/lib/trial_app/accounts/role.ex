defmodule TrialApp.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :description, :string
    field :is_system_role, :boolean, default: false

    many_to_many :permissions, TrialApp.Accounts.Permission,
      join_through: "role_permissions",
      on_replace: :delete

    has_many :users, TrialApp.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description, :is_system_role])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> validate_length(:name, min: 2, max: 50)
  end

  @doc """
  Changeset for creating a new role with permissions.
  """
  def create_changeset(role, attrs) do
    role
    |> changeset(attrs)
    |> put_assoc(:permissions, attrs[:permissions] || [])
  end

  @doc """
  Returns a role with permissions preloaded.
  """
  def with_permissions(role) do
    TrialApp.Repo.preload(role, :permissions)
  end
end
