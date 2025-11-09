defmodule TrialAppWeb.DashboardLive do
  use TrialAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Get the current user's role
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    active_role = user.active_role

    # Redirect to appropriate dashboard based on role
    case active_role do
      "attachee" ->
        {:ok, push_navigate(socket, to: ~p"/attachee")}

      "supervisor" ->
        {:ok, push_navigate(socket, to: ~p"/supervisor/dashboard")}

      "admin" ->
        {:ok, push_navigate(socket, to: ~p"/admin/dashboard")}

      _ ->
        # Default fallback - redirect to attachee dashboard
        {:ok, push_navigate(socket, to: ~p"/attachee")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-screen">
      <div class="text-center">
        <div class="loading loading-spinner loading-lg text-primary"></div>
        <p class="mt-4 text-base-content/70">Redirecting to your dashboard...</p>
      </div>
    </div>
    """
  end
end
