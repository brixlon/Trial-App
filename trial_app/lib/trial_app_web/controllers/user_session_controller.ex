defmodule TrialAppWeb.UserSessionController do
  use TrialAppWeb, :controller

  alias TrialApp.Accounts
  alias TrialAppWeb.UserAuth

  # -------------------------------------------------------------------------
  # LOGIN VIA USER ID (Redirected from LiveView) - MUST BE FIRST!
  # -------------------------------------------------------------------------
  def login(conn, %{"user_id" => user_id}) do
    user = Accounts.get_user!(user_id)

    if user.must_change_password do
      conn
      |> put_flash(:info, "You must change your password before continuing.")
      |> redirect(to: ~p"/users/force_password_change?user_id=#{user.id}")
    else
      conn
      |> put_flash(:info, "Welcome back, #{user.username}!")
      |> UserAuth.log_in_user(user, %{})
    end
  end

  # -------------------------------------------------------------------------
  # REDIRECT TO LIVEVIEW LOGIN (GET /users/login without params)
  # -------------------------------------------------------------------------
  def login(conn, _params) do
    redirect(conn, to: ~p"/")
  end

  # -------------------------------------------------------------------------
  # STANDARD EMAIL/PASSWORD LOGIN (API Style)
  # -------------------------------------------------------------------------
  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        if user.must_change_password do
          conn
          |> put_flash(:info, "You must change your password before continuing.")
          |> redirect(to: ~p"/users/force_password_change?user_id=#{user.id}")
        else
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, %{})
        end

      nil ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/users/login")
    end
  end

  # -------------------------------------------------------------------------
  # UPDATE PASSWORD (from Force Password Change)
  # -------------------------------------------------------------------------
  def update_password(conn, %{"user_id" => user_id, "user" => user_params}) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_password(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> UserAuth.log_in_user(user, %{})

      {:error, changeset} ->
        render(conn, "force_password_change.html", changeset: changeset)
    end
  end

  # -------------------------------------------------------------------------
  # PASSWORD RESET & FORCE CHANGE
  # -------------------------------------------------------------------------
  def reset_password_form(conn, _params), do: render(conn, "reset_password.html")
  def reset_password(conn, _params), do: redirect(conn, to: ~p"/users/login")

  def force_password_change_form(conn, %{"user_id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "force_password_change.html", user: user)
  end

  def force_password_change(conn, _params), do: redirect(conn, to: ~p"/dashboard")

  # -------------------------------------------------------------------------
  # LOGOUT
  # -------------------------------------------------------------------------
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
