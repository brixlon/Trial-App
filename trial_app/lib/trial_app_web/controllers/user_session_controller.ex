defmodule TrialAppWeb.UserSessionController do
  use TrialAppWeb, :controller

  alias TrialApp.Accounts
  alias TrialAppWeb.UserAuth

  # -------------------------------------------------------------------------
  # LOGIN VIA USER ID (Redirected from LiveView)
  # -------------------------------------------------------------------------
  def login(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    if user.must_change_password do
      conn
      |> put_flash(:info, "You must change your password before continuing.")
      |> redirect(to: ~p"/users/force_password_change?user_id=#{user.id}")
    else
      # CRITICAL FIX: Ensure active_role is set before getting dashboard path
      {:ok, user_with_role} = Accounts.ensure_active_role(user)
      redirect_path = get_dashboard_for_active_role(user_with_role)

      conn
      |> put_flash(:info, "Welcome back, #{user_with_role.username}!")
      |> UserAuth.log_in_user(user_with_role, %{"return_to" => redirect_path})
    end
  end

  # -------------------------------------------------------------------------
  # STANDARD EMAIL/PASSWORD LOGIN (API Style)
  # -------------------------------------------------------------------------
  def create(conn, %{"user" => %{"email" => email, "password" => password}} = _params) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        if user.must_change_password do
          conn
          |> put_flash(:info, "You must change your password before continuing.")
          |> redirect(to: ~p"/users/force_password_change?user_id=#{user.id}")
        else
          # CRITICAL FIX: Ensure active_role is set before getting dashboard path
          {:ok, user_with_role} = Accounts.ensure_active_role(user)
          redirect_path = get_dashboard_for_active_role(user_with_role)

          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user_with_role, %{"return_to" => redirect_path})
        end

      nil ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/users/login")
    end
  end

  # -------------------------------------------------------------------------
  # DIRECT LOGIN (if you have this route)
  # -------------------------------------------------------------------------
  def direct(conn, _params) do
    # Render login page or handle direct login
    render(conn, "login.html")
  end

  # -------------------------------------------------------------------------
  # UPDATE PASSWORD (from Force Password Change)
  # -------------------------------------------------------------------------
  def update_password(conn, %{"user_id" => user_id, "user" => user_params}) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_password(user, user_params) do
      {:ok, {updated_user, _tokens}} ->
        # CRITICAL FIX: Ensure active_role is set
        {:ok, user_with_role} = Accounts.ensure_active_role(updated_user)
        redirect_path = get_dashboard_for_active_role(user_with_role)

        conn
        |> put_flash(:info, "Password updated successfully.")
        |> UserAuth.log_in_user(user_with_role, %{"return_to" => redirect_path})

      {:error, changeset} ->
        # Render the force password change page with errors
        render(conn, "force_password_change.html",
          changeset: changeset,
          user_id: user_id
        )
    end
  end

  # -------------------------------------------------------------------------
  # LOGOUT
  # -------------------------------------------------------------------------
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  # -------------------------------------------------------------------------
  # PRIVATE HELPERS
  # -------------------------------------------------------------------------

  # Get the dashboard path based on user's active role
  defp get_dashboard_for_active_role(user) do
    active_role = user.active_role || Accounts.get_active_role(user)

    case active_role do
      "admin" -> ~p"/admin/dashboard"
      "supervisor" -> ~p"/supervisor/dashboard"
      "attachee" -> ~p"/attachee"
      "manager" -> ~p"/dashboard"
      _ -> ~p"/dashboard"
    end
  end
end
