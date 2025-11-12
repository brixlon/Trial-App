# lib/trial_app_web/live/supervisor_live/team.ex
defmodule TrialAppWeb.SupervisorLive.Team do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">Team page – coming soon</div>
    """
  end
end
