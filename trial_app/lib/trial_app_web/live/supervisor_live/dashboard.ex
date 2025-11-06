defmodule TrialAppWeb.SupervisorLive.Dashboard do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Supervisor Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-3xl font-bold">Supervisor Dashboard</h1>
      <p class="mt-4">Manage your team of attachees here.</p>
    </div>
    """
  end
end
