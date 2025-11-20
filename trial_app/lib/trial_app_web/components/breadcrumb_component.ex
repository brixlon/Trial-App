# lib/trial_app_web/components/breadcrumb_component.ex
defmodule TrialAppWeb.BreadcrumbComponent do
  use Phoenix.Component

  attr :items, :list, required: true

  def breadcrumb(assigns) do
    ~H"""
    <nav class="flex items-center space-x-2 text-sm text-gray-600 mb-6">
      <%= for {item, index} <- Enum.with_index(@items) do %>
        <%= if index > 0 do %>
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        <% end %>

        <%= if item.link && index < length(@items) - 1 do %>
          <.link
            navigate={item.link}
            class="hover:text-purple-600 transition-colors font-medium"
          >
            <%= item.label %>
          </.link>
        <% else %>
          <span class={if index == length(@items) - 1, do: "font-semibold text-gray-900", else: "text-gray-500"}>
            <%= item.label %>
          </span>
        <% end %>
      <% end %>
    </nav>
    """
  end
end
