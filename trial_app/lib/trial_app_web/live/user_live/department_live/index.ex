defmodule TrialAppWeb.DepartmentLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>Departments (Placeholder)</div>
    """
  end
end
