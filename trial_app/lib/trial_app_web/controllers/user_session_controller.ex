defmodule TrialAppWeb.UserSessionController do
  use TrialAppWeb, :controller

  alias TrialApp.Accounts
  alias TrialAppWeb.UserAuth

  # -------------------------------------------------------------------------
  # LOGIN PAGE (GET) - Show login form or redirect if already logged in
  # -------------------------------------------------------------------------
  def login(conn, params) when is_map(params) and map_size(params) == 0 do
    # If user is already logged in, redirect to dashboard
    if conn.assigns[:current_user] do
      user = conn.assigns.current_user
      {:ok, user_with_role} = Accounts.ensure_active_role(user)
      redirect_path = get_dashboard_for_active_role(user_with_role)

      conn
      |> redirect(to: redirect_path)
    else
      # Redirect to the LiveView login page at root
      redirect(conn, to: "/")
    end
  end

  # -------------------------------------------------------------------------
  # LOGIN VIA USER ID (Redirected from LiveView)
  # -------------------------------------------------------------------------
  def login(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    if user.must_change_password do
      token = Accounts.generate_force_reset_token(user)

      conn
      |> put_flash(:info, "You must change your password before continuing.")
      |> redirect(to: ~p"/users/force-reset/#{token}")
    else
      # CRITICAL FIX: Ensure active_role is set before getting dashboard path
      {:ok, user_with_role} = Accounts.ensure_active_role(user)
      redirect_path = get_dashboard_for_active_role(user_with_role)

      conn
      # |> put_flash(:info, "Welcome back, #{user_with_role.username}!")
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
          token = Accounts.generate_force_reset_token(user)

          conn
          |> put_flash(:info, "You must change your password before continuing.")
          |> redirect(to: ~p"/users/force-reset/#{token}")
        else
          # CRITICAL FIX: Ensure active_role is set before getting dashboard path
          {:ok, user_with_role} = Accounts.ensure_active_role(user)
          redirect_path = get_dashboard_for_active_role(user_with_role)

          conn
          #  |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user_with_role, %{"return_to" => redirect_path})
        end

      nil ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/")
    end
  end

  # -------------------------------------------------------------------------
  # USERNAME OR EMAIL LOGIN (Alternative login method)
  # -------------------------------------------------------------------------
  def create(
        conn,
        %{"user" => %{"username_or_email" => username_or_email, "password" => password}} =
          user_params
      ) do
    if user = Accounts.get_user_by_username_or_email_and_password(username_or_email, password) do
      # Check if user must change password
      if user.must_change_password do
        token = Accounts.generate_force_reset_token(user)

        conn
        |> put_flash(:info, "You must change your password before continuing.")
        |> redirect(to: ~p"/users/force-reset/#{token}")
      else
        {:ok, user_with_role} = Accounts.ensure_active_role(user)
        _redirect_path = get_dashboard_for_active_role(user_with_role)

        conn
        # |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user_with_role, user_params)
      end
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid username/email or password")
      |> redirect(to: ~p"/")
    end
  end

  # -------------------------------------------------------------------------
  # DIRECT LOGIN WITH SESSION TOKEN (from Force Password Reset)
  # -------------------------------------------------------------------------
  def direct(conn, %{"token" => encoded_token}) do
    # Decode the Base64-encoded session token
    token =
      case Base.url_decode64(encoded_token, padding: false) do
        {:ok, decoded} -> decoded
        :error -> nil
      end

    if token do
      case Accounts.get_user_by_session_token(token) do
        {user, _token_inserted_at} ->
          # Ensure active_role is set
          {:ok, user_with_role} = Accounts.ensure_active_role(user)
          redirect_path = get_dashboard_for_active_role(user_with_role)

          conn
          |> put_session(:user_token, token)
          |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
          |> configure_session(renew: true)
          |> put_flash(:info, "Password set successfully! Welcome!")
          |> redirect(to: redirect_path)

        nil ->
          conn
          |> put_flash(:error, "Invalid or expired session token.")
          |> redirect(to: ~p"/")
      end
    else
      conn
      |> put_flash(:error, "Invalid session token format.")
      |> redirect(to: ~p"/")
    end
  end

  # DIRECT LOGIN VIA USER ID (existing functionality)
  def direct(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    if user.must_change_password do
      token = Accounts.generate_force_reset_token(user)

      conn
      |> put_flash(:info, "You must change your password before continuing.")
      |> redirect(to: ~p"/users/force-reset/#{token}")
    else
      {:ok, user_with_role} = Accounts.ensure_active_role(user)
      _redirect_path = get_dashboard_for_active_role(user_with_role)

      UserAuth.log_in_user(conn, user_with_role)
    end
  end

  def direct(conn, _params) do
    # Redirect to main login page
    redirect(conn, to: ~p"/")
  end

  # -------------------------------------------------------------------------
  # UPDATE PASSWORD PAGE (GET) - Redirect to LiveView for password reset
  # -------------------------------------------------------------------------
  def update_password(conn, %{"user_id" => user_id}) do
    # Instead of rendering a template, redirect to the LiveView force reset page
    # You'll need to generate a token or use the existing force-reset flow
    conn
    |> put_flash(:info, "Please update your password to continue.")
    |> redirect(to: ~p"/users/force-reset/#{generate_temp_token(user_id)}")
  end

  # -------------------------------------------------------------------------
  # UPDATE PASSWORD (POST - from Force Password Change)
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

      {:error, _changeset} ->
        token = Accounts.generate_force_reset_token(user)

        conn
        |> put_flash(:error, "Failed to update password. Please try again.")
        |> redirect(to: ~p"/users/force-reset/#{token}")
    end
  end

  # Alternative pattern for POST with different structure
  def update_password(conn, %{
        "user" => %{
          "user_id" => user_id,
          "current_password" => current_password,
          "password" => password,
          "password_confirmation" => password_confirmation
        }
      }) do
    user = Accounts.get_user!(user_id)

    # Verify current password
    if Accounts.get_user_by_username_or_email_and_password(
         user.username || user.email,
         current_password
       ) do
      # Validate new password
      if password == password_confirmation && String.length(password) >= 8 do
        # Update password
        case Accounts.update_user_password(user, %{password: password}) do
          {:ok, {updated_user, _tokens}} ->
            {:ok, user_with_role} = Accounts.ensure_active_role(updated_user)
            redirect_path = get_dashboard_for_active_role(user_with_role)

            conn
            |> put_flash(:info, "Password changed successfully!")
            |> UserAuth.log_in_user(user_with_role, %{"return_to" => redirect_path})

          {:error, _changeset} ->
            conn
            |> put_flash(:error, "Failed to update password. Please try again.")
            |> redirect(to: ~p"/users/force-reset/#{Accounts.generate_force_reset_token(user)}")
        end
      else
        error_msg =
          if password != password_confirmation do
            "Passwords do not match"
          else
            "Password must be at least 8 characters"
          end

        token = Accounts.generate_force_reset_token(user)

        conn
        |> put_flash(:error, error_msg)
        |> redirect(to: ~p"/users/force-reset/#{token}")
      end
    else
      conn
      |> put_flash(:error, "Current password is incorrect")
      |> redirect(to: ~p"/users/force-reset/#{Accounts.generate_force_reset_token(user)}")
    end
  end

  def update_password(conn, _params) do
    redirect(conn, to: ~p"/")
  end

  # -------------------------------------------------------------------------
  # LOGOUT
  # -------------------------------------------------------------------------
  def delete(conn, _params) do
    conn
    # |> put_flash(:info, "Logged out successfully.")
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

  # Generate a temporary token for password reset
  defp generate_temp_token(user_id) do
    # You can implement proper token generation here
    # For now, using a simple approach - consider using proper token generation
    "temp_#{user_id}_#{System.system_time(:second)}"
  end
end
