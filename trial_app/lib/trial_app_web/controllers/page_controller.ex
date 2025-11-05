defmodule TrialAppWeb.PageController do
  use TrialAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  # NEW: Redirect root (/) to login page
  def redirect_to_login(conn, _params) do
    redirect(conn, to: ~p"/users/login")
  end
end
