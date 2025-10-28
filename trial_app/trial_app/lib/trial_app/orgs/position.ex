defmodule TrialApp.Orgs.Position do
  use Ecto.Schema
  import Ecto.Changeset

  schema "positions" do
    field :title, :string
    field :name, :string
    field :description, :string
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(position, attrs) do
    position
    |> cast(attrs, [:name, :title, :description, :is_active])
    |> ensure_title_from_name()
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> validate_length(:name, min: 2, max: 100)
    |> unique_constraint(:name)
  end

  defp ensure_title_from_name(changeset) do
    title = get_field(changeset, :title)
    name = get_field(changeset, :name)

    cond do
      is_binary(title) and String.trim(title) != "" -> changeset
      is_binary(name) and String.trim(name) != "" -> put_change(changeset, :title, name)
      true -> changeset
    end
  end
end
