defmodule TrialAppWeb.PageController do
  use TrialAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
