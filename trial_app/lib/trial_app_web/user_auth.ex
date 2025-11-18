defmodule TrialAppWeb.UserAuth do
  use TrialAppWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias TrialApp.Accounts
  alias TrialApp.Accounts.Scope

  @max_cookie_age_in_days 14
  @remember_me_cookie "_trial_app_web_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax"
  ]

  @session_reissue_age_in_days 7

  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> create_or_extend_session(user, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      TrialAppWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  def fetch_current_scope_for_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, token_inserted_at} <- Accounts.get_user_by_session_token(token) do
      {:ok, user_with_role} = Accounts.ensure_active_role(user)

      conn
      |> assign(:current_scope, Scope.for_user(user_with_role))
      |> maybe_reissue_user_session_token(user_with_role, token_inserted_at)
    else
      nil -> assign(conn, :current_scope, Scope.for_user(nil))
    end
  end

  defp ensure_user_token(conn) do
    cond do
      token = get_session(conn, :user_token) ->
        {token, conn}

      token = conn.params["user_token"] ->
        decoded_token = decode_url_token(token)
        {decoded_token, conn |> put_token_in_session(decoded_token)}

      true ->
        conn = fetch_cookies(conn, signed: [@remember_me_cookie])

        if token = conn.cookies[@remember_me_cookie] do
          {token, conn |> put_token_in_session(token) |> put_session(:user_remember_me, true)}
        else
          nil
        end
    end
  end

  defp decode_url_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} -> decoded
      :error -> token
    end
  end

  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user, %{})
    else
      conn
    end
  end

  defp create_or_extend_session(conn, user, params) do
    token = Accounts.generate_user_session_token(user)
    remember_me = get_session(conn, :user_remember_me)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  defp renew_session(conn, user) when is_map(user) do
    case conn.assigns[:current_scope] do
      %{user: %{id: user_id}} when user_id == user.id ->
        conn

      _ ->
        delete_csrf_token()

        conn
        |> configure_session(renew: true)
        |> clear_session()
    end
  end

  defp renew_session(conn, nil) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      TrialAppWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
    end)
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/login")

      {:halt, socket}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    socket = mount_current_scope(socket, session)


    if socket.assigns.current_scope && socket.assigns.current_scope.user &&
         socket.assigns.current_scope.user.role == "admin" do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be an administrator to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    end
  end

  # Allow both admin AND supervisor to access supervisor pages
  def on_mount(:require_supervisor_or_admin, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    user = socket.assigns.current_scope.user
    active_role = if user, do: Accounts.get_active_role(user), else: nil

    if user && active_role in ["admin", "supervisor"] do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "You must be a supervisor or admin to access this page."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must re-authenticate to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/login")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        case session["user_token"] do
          nil ->
            nil

          token ->
            case Accounts.get_user_by_session_token(token)
   do
              {u, _} ->
                case Accounts.ensure_active_role(u) do
                  {:ok, user_with_role} -> user_with_role
                  _ -> u
                end

              nil ->
                nil
            end
        end

      Scope.for_user(user)
    end)
  end

  def signed_in_path(%Plug.Conn{
        assigns: %{current_scope: %Scope{user: %Accounts.User{active_role: active_role}}}
      })
      when not is_nil(active_role) do
    case active_role do
      "admin" -> ~p"/admin/dashboard"
      "supervisor" -> ~p"/supervisor/dashboard"
      "attachee" -> ~p"/attachee"
      "manager" -> ~p"/dashboard"
      _ -> ~p"/dashboard"

    end
  end

  def signed_in_path(%Plug.Conn{
        assigns: %{current_scope: %Scope{user: %Accounts.User{roles: roles}}}
      }) do
    if Enum.any?(["admin", "supervisor"], &(&1 in roles)) do
      ~p"/admin/dashboard"
    else
      ~p"/"
    end
  end

  def signed_in_path(%Plug.Conn{assigns: %{current_scope: %Scope{user: %Accounts.User{} }}}) do
    ~p"/dashboard"
  end

  def signed_in_path(_), do: ~p"/dashboard"

  def require_authenticated_user(conn, _opts) do
    IO.inspect(conn, label: "require_authenticated_user CONN")
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/login")
      |> halt()
    end
  end

  # FIXED: Use `conn`, not `socket`
  def require_admin_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         "admin" in conn.assigns.current_scope.user.roles do
      conn
    else
      conn
      |> put_flash(:error, "You must be an administrator to access this page.")
      |> redirect(to: ~p"/dashboard")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
