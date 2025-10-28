defmodule TrialApp.Orgs.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ["member", "lead", "manager", "admin"]
  @statuses ~w(active inactive suspended)

  schema "employees" do
    field :name, :string
    field :email, :string
    field :role, :string, default: "member"
    field :position, :string
    field :is_active, :boolean, default: true
    field :status, :string, default: "active"

    belongs_to :user, TrialApp.Accounts.User
    belongs_to :team, TrialApp.Orgs.Team
    belongs_to :department, TrialApp.Orgs.Department
    belongs_to :organization, TrialApp.Orgs.Organization

    timestamps()
  end

  @doc """
  Standard changeset for employee operations.
  """
  def changeset(employee, attrs) do
    employee
    |> cast(attrs, [
      :name,
      :email,
      :role,
      :position,
      :is_active,
      :status,
      :user_id,
      :team_id,
      :department_id,
      :organization_id
    ])
    |> validate_required([:name, :email, :user_id, :team_id])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:status, @statuses)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> assoc_constraint(:user)
    |> assoc_constraint(:team)
    |> assoc_constraint(:department)
    |> assoc_constraint(:organization)
    |> unique_constraint([:user_id, :team_id])
  end

  @doc """
  Changeset for creating a new employee assignment.
  """
  def create_changeset(employee, attrs) do
    employee
    |> changeset(attrs)
    |> set_name_and_email_from_user()
  end

  defp set_name_and_email_from_user(changeset) do
    user_id = get_field(changeset, :user_id)

    if user_id && (!get_field(changeset, :name) || !get_field(changeset, :email)) do
      user = TrialApp.Repo.get(TrialApp.Accounts.User, user_id)

      if user do
        changeset
        |> put_change(:name, get_field(changeset, :name) || user.username || user.email)
        |> put_change(:email, get_field(changeset, :email) || user.email)
      else
        changeset
      end
    else
      changeset
    end
  end

  @doc """
  Returns an employee with all relationships preloaded.
  """
  def with_preloads(employee) do
    TrialApp.Repo.preload(employee, [
      :user,
      :team,
      :department,
      :organization
    ])
  end

  @doc """
  Returns true if employee is active.
  """
  def active?(employee) do
    employee.is_active && employee.status == "active"
  end
end
