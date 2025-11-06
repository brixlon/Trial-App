defmodule TrialAppWeb.RoleBadge do
  use TrialAppWeb, :html

  def role_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
      <%= TrialApp.Accounts.Scope.role_display_name(@role) %>
    </span>
    """
  end
end
