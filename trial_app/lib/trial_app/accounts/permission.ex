defmodule TrialApp.Accounts.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "permissions" do
    field :slug, :string
    field :description, :string
    field :category, :string

    many_to_many :roles, TrialApp.Accounts.Role, join_through: "role_permissions"

    timestamps()
  end

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:slug, :description, :category])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
    |> validate_length(:slug, min: 2, max: 100)
    |> validate_format(:slug, ~r/^[a-z_]+$/, message: "must be lowercase with underscores only")
  end

  @doc """
  Groups permissions by category for display purposes.
  """
  def group_by_category(permissions) do
    Enum.group_by(permissions, & &1.category)
  end
end
