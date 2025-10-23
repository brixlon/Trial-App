# lib/trial_app_web/live/sidebar_component.ex
defmodule TrialAppWeb.SidebarComponent do
  use TrialAppWeb, :live_component

  def render(assigns) do
    ~H"""
    <aside class="w-64 bg-gradient-to-b from-purple-500 to-purple-700 text-white h-screen fixed top-0 left-0 p-6 shadow-lg">
      <div class="mb-8">
        <h1 class="text-2xl font-bold">Integra<span class="text-purple-300">8</span></h1>
      </div>
      <nav>
        <ul class="space-y-4">
          <li>
            <.link navigate={~p"/dashboard"} class="block py-2 px-4 rounded hover:bg-purple-600 transition-colors font-medium">
              Dashboard
            </.link>
          </li>
          <li>
            <.link navigate={~p"/organizations"} class="block py-2 px-4 rounded hover:bg-purple-600 transition-colors font-medium">
              Organizations
            </.link>
          </li>
          <li>
            <.link navigate={~p"/users/settings"} class="block py-2 px-4 rounded hover:bg-purple-600 transition-colors font-medium">
              Settings
            </.link>
          </li>
        </ul>
      </nav>
    </aside>
    """
  end
end
