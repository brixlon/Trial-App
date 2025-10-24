defmodule TrialAppWeb.Plugs.RequireAdmin do
  import Plug.Conn
  import Phoenix.Controller
  alias TrialAppWeb.Router.Helpers, as: Routes

  def init(default), do: default

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && user.role == "admin" do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to access this page.")
      |> redirect(to: Routes.dashboard_live_path(conn, :index))
      |> halt()
    end
  end
end
