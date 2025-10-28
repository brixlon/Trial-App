defmodule TrialAppWeb.Layouts do
  use TrialAppWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page_title, :string, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" data-theme="light">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Trial App</title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
      </head>

      <body class="min-h-screen bg-gradient-to-br from-purple-50 via-white to-purple-100 text-gray-800 font-inter">
        <%= if @current_scope && @current_scope.user && @current_scope.user.role == "admin" do %>
          <.admin_layout flash={@flash} current_user={@current_scope.user}>
            <%= render_slot(@inner_block) %>
          </.admin_layout>
        <% else %>
          <.public_layout flash={@flash}>
            <%= render_slot(@inner_block) %>
          </.public_layout>
        <% end %>
      </body>
    </html>
    """
  end

  # ——————————————————————————————————
  # ADMIN LAYOUT
  # ——————————————————————————————————
  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def admin_layout(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gradient-to-br from-purple-50 via-white to-purple-100">
      <!-- Sidebar -->
      <.live_component module={TrialAppWeb.SidebarComponent} id="sidebar" current_scope={%{user: @current_user}} />

      <!-- Main Content Area -->
      <div class="flex flex-col flex-1 ml-64">
        <.topbar current_user={@current_user} />

        <main class="flex-1 p-8">
          <div class="bg-white/70 backdrop-blur-sm rounded-2xl shadow-lg p-6 border border-purple-100">
            <%= render_slot(@inner_block) %>
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  # ——————————————————————————————————
  # PUBLIC LAYOUT
  # ——————————————————————————————————
  attr :flash, :map, required: true
  slot :inner_block, required: true

  def public_layout(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-gradient-to-br from-purple-50 via-white to-purple-100">
      <.topbar />
      <main class="flex-1 flex items-center justify-center p-8">
        <div class="bg-white/70 backdrop-blur-sm rounded-2xl shadow-lg p-8 border border-purple-100 w-full max-w-3xl">
          <%= render_slot(@inner_block) %>
        </div>
      </main>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  # ——————————————————————————————————
  # TOPBAR
  # ——————————————————————————————————
  attr :current_user, :map, default: nil

  def topbar(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 bg-white/80 backdrop-blur-md shadow-sm border-b border-purple-100 flex items-center justify-between px-6 py-3">
      <!-- Left -->
      <div class="flex items-center space-x-3">
        <a href="/" class="text-2xl font-extrabold bg-gradient-to-r from-purple-700 to-indigo-600 bg-clip-text text-transparent tracking-tight">
          trial<span class="text-gray-800">app</span>
        </a>
      </div>

      <!-- Right -->
      <div class="flex items-center gap-4">
        <.theme_toggle />

        <%= if @current_user do %>
          <div class="relative group">
            <div class="w-9 h-9 rounded-full bg-gradient-to-br from-purple-600 to-indigo-600 text-white flex items-center justify-center font-bold cursor-pointer select-none">
              <%= String.first(@current_user.username || "U") |> String.upcase() %>
            </div>
            <div class="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-lg border border-purple-100 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
              <div class="px-4 py-2 text-sm text-gray-700 border-b border-purple-50">
                <%= @current_user.username %><br />
                <span class="text-xs text-gray-500">
                  <%= if @current_user.role == "admin", do: "Administrator", else: "User" %>
                </span>
              </div>
              <a href={~p"/users/settings"} class="block px-4 py-2 text-sm hover:bg-purple-50">Settings</a>
              <a href={~p"/users/logout"} phx-click={JS.push("logout")} class="block px-4 py-2 text-sm text-red-600 hover:bg-red-50">Logout</a>
            </div>
          </div>
        <% else %>
          <a href={~p"/users/login"} class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition">Login</a>
        <% end %>
      </div>
    </header>
    """
  end

  # ——————————————————————————————————
  # FLASH GROUP
  # ——————————————————————————————————
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="fixed top-4 right-4 z-50 space-y-2" aria-live="polite">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
      <.flash
        id="disconnected"
        kind={:error}
        title="Offline"
        phx-disconnected={show("#disconnected")}
        phx-connected={hide("#disconnected")}
        hidden
      >
        Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 inline animate-spin" />
      </.flash>
    </div>
    """
  end

  # ——————————————————————————————————
  # THEME TOGGLE
  # ——————————————————————————————————
  def theme_toggle(assigns) do
    ~H"""
    <div class="flex items-center gap-1 bg-white/60 rounded-full border border-purple-100 shadow-inner p-1 backdrop-blur-sm">
      <button phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light" class="p-2 rounded-full hover:bg-purple-50">
        <.icon name="hero-sun" class="w-4 h-4 text-purple-700" />
      </button>
      <button phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark" class="p-2 rounded-full hover:bg-purple-50">
        <.icon name="hero-moon" class="w-4 h-4 text-purple-700" />
      </button>
    </div>
    """
  end
end
