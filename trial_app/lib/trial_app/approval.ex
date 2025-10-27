defmodule TrialApp.Approval do
  @moduledoc """
  The Approval context.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo

  alias TrialApp.Approval.UserApproval
  alias TrialApp.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any user_approval changes.

  The broadcasted messages match the pattern:

    * {:created, %UserApproval{}}
    * {:updated, %UserApproval{}}
    * {:deleted, %UserApproval{}}

  """
  def subscribe_users(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(TrialApp.PubSub, "user:#{key}:users")
  end

  defp broadcast_user_approval(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(TrialApp.PubSub, "user:#{key}:users", message)
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users(scope)
      [%UserApproval{}, ...]

  """
  def list_users(%Scope{} = scope) do
    Repo.all_by(UserApproval, user_id: scope.user.id)
  end

  @doc """
  Gets a single user_approval.

  Raises `Ecto.NoResultsError` if the User approval does not exist.

  ## Examples

      iex> get_user_approval!(scope, 123)
      %UserApproval{}

      iex> get_user_approval!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_user_approval!(%Scope{} = scope, id) do
    Repo.get_by!(UserApproval, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a user_approval.

  ## Examples

      iex> create_user_approval(scope, %{field: value})
      {:ok, %UserApproval{}}

      iex> create_user_approval(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_approval(%Scope{} = scope, attrs) do
    with {:ok, user_approval = %UserApproval{}} <-
           %UserApproval{}
           |> UserApproval.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_user_approval(scope, {:created, user_approval})
      {:ok, user_approval}
    end
  end

  @doc """
  Updates a user_approval.

  ## Examples

      iex> update_user_approval(scope, user_approval, %{field: new_value})
      {:ok, %UserApproval{}}

      iex> update_user_approval(scope, user_approval, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_approval(%Scope{} = scope, %UserApproval{} = user_approval, attrs) do
    true = user_approval.user_id == scope.user.id

    with {:ok, user_approval = %UserApproval{}} <-
           user_approval
           |> UserApproval.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_user_approval(scope, {:updated, user_approval})
      {:ok, user_approval}
    end
  end

  @doc """
  Deletes a user_approval.

  ## Examples

      iex> delete_user_approval(scope, user_approval)
      {:ok, %UserApproval{}}

      iex> delete_user_approval(scope, user_approval)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_approval(%Scope{} = scope, %UserApproval{} = user_approval) do
    true = user_approval.user_id == scope.user.id

    with {:ok, user_approval = %UserApproval{}} <-
           Repo.delete(user_approval) do
      broadcast_user_approval(scope, {:deleted, user_approval})
      {:ok, user_approval}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_approval changes.

  ## Examples

      iex> change_user_approval(scope, user_approval)
      %Ecto.Changeset{data: %UserApproval{}}

  """
  def change_user_approval(%Scope{} = scope, %UserApproval{} = user_approval, attrs \\ %{}) do
    true = user_approval.user_id == scope.user.id

    UserApproval.changeset(user_approval, attrs, scope)
  end
end
