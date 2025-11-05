defmodule TrialApp.Eams.Attachee do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active suspended completed)

  schema "attachees" do
    field :status, :string, default: "active"
    field :starts_on, :date
    field :ends_on, :date

    belongs_to :user, TrialApp.Accounts.User
    belongs_to :organization, TrialApp.Orgs.Organization
    belongs_to :department, TrialApp.Orgs.Department

    has_many :tasks, TrialApp.Eams.Task, foreign_key: :assignee_id

    timestamps()
  end

  def changeset(attachee, attrs) do
    attachee
    |> cast(attrs, [:status, :starts_on, :ends_on, :user_id, :organization_id, :department_id])
    |> validate_required([:user_id, :organization_id, :department_id])
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:user)
    |> assoc_constraint(:organization)
    |> assoc_constraint(:department)
    |> unique_constraint([:user_id, :department_id], name: :attachees_user_id_department_id_index)
  end

  def create_changeset(attachee, attrs), do: changeset(attachee, attrs)
  def update_changeset(attachee, attrs), do: changeset(attachee, attrs)
end
