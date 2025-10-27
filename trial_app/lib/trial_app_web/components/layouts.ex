defmodule TrialAppWeb.Layouts do
  use TrialAppWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="[&.phx-no-feedback]:tw-invisible" data-theme="light">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Trial App</title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
      </head>
      <body class="min-h-screen bg-base-200">
        <%= if @current_scope && @current_scope.role == :admin do %>
          <.admin_layout flash={@flash} current_user={@current_scope}>
            {@inner_block}
          </.admin_layout>
        <% else %>
          <.public_layout flash={@flash}>
            {@inner_block}
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
    <div class="drawer lg:drawer-open">
      <input id="sidebar-drawer" type="checkbox" class="drawer-toggle" />

      <!-- Main Content -->
      <div class="drawer-content flex flex-col">
        <.topbar current_user={@current_user} />
        <main class="flex-1 p-6">
          <div class="mx-auto max-w-7xl">
            {@inner_block}
          </div>
        </main>
      </div>

      <!-- Sidebar -->
      <div class="drawer-side">
        <label for="sidebar-drawer" class="drawer-overlay"></label>
        <aside class="w-64 min-h-full bg-base-100 text-base-content">
          <div class="p-4 border-b">
            <a href="/admin" class="flex items-center gap-2">
              <img src={~p"/images/logo.svg"} class="w-8" />
              <span class="font-bold">Trial Admin</span>
            </a>
          </div>
          <ul class="menu p-4 space-y-1 text-sm">
            <.sidebar_link href={~p"/admin/pending-approvals"} current_path={@current_user.current_path}>
              User Approvals
            </.sidebar_link>
            <.sidebar_link href={~p"/admin/organizations"} current_path={@current_user.current_path}>
              Organizations
            </.sidebar_link>
            <.sidebar_link href={~p"/admin/users"} current_path={@current_user.current_path}>
              All Users
            </.sidebar_link>
            <.sidebar_link href={~p"/admin/teams"} current_path={@current_user.current_path}>
              Teams
            </.sidebar_link>
          </ul>
        </aside>
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
    <div class="min-h-screen bg-base-200 flex flex-col">
      <.topbar />
      <main class="flex-1 p-6">
        <div class="mx-auto max-w-3xl">
          {@inner_block}
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
    <header class="navbar bg-base-100 shadow-sm">
      <div class="flex-1">
        <label for="sidebar-drawer" class="btn btn-square btn-ghost lg:hidden">
          <.icon name="hero-bars-3" class="w-5 h-5" />
        </label>
        <a href="/" class="ml-2 text-xl font-bold">Trial App</a>
      </div>
      <div class="flex-none gap-2">
        <.theme_toggle />
        <%= if @current_user do %>
          <div class="dropdown dropdown-end">
            <label tabindex="0" class="btn btn-ghost btn-circle avatar">
              <div class="w-8 rounded-full bg-primary text-primary-content flex items-center justify-center">
                <%= String.first(@current_user.email) %>
              </div>
            </label>
            <ul tabindex="0" class="menu dropdown-content mt-3 p-2 shadow bg-base-100 rounded-box w-52">
              <li><a href={~p"/users/settings"}>Settings</a></li>
              <li><a href={~p"/users/log_out"} phx-click={JS.push("logout")}>Logout</a></li>
            </ul>
          </div>
        <% else %>
          <a href={~p"/users/log_in"} class="btn btn-primary btn-sm">Login</a>
        <% end %>
      </div>
    </header>
    """
  end

  # ——————————————————————————————————
  # SIDEBAR LINK
  # ——————————————————————————————————
  attr :href, :string, required: true
  attr :current_path, :string, required: true
  slot :inner_block, required: true

  def sidebar_link(assigns) do
    active = assigns.current_path == assigns.href
    assigns = assign(assigns, :active, active)

    ~H"""
    <li>
      <a href={@href} class={"#{if @active, do: "bg-primary text-white", else: "hover:bg-base-200"}"}>
        {@inner_block}
      </a>
    </li>
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
    <div class="flex items-center gap-1 p-1 bg-base-300 rounded-full relative w-28 h-10">
      <div id="theme-slider" class="absolute w-8 h-8 bg-base-100 rounded-full shadow-md transition-left duration-300 left-1 [[data-theme=light]_&]:left-10 [[data-theme=dark]_&]:left-20"></div>

      <button phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system" class="z-10 p-1">
        <.icon name="hero-computer-desktop" class="w-5 h-5" />
      </button>
      <button phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light" class="z-10 p-1">
        <.icon name="hero-sun" class="w-5 h-5" />
      </button>
      <button phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark" class="z-10 p-1">
        <.icon name="hero-moon" class="w-5 h-5" />
      </button>
    </div>
    """
  end
end
