defmodule TrialAppWeb.Router do
  use TrialAppWeb, :router

  import TrialAppWeb.UserAuth
  import Plug.Conn

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TrialAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_custom_permissions_policy
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Admin pipeline - requires admin role
  pipeline :admin do
    plug :require_admin_user
  end

  scope "/", TrialAppWeb do
    pipe_through :browser

    get "/home", PageController, :home
    live "/", UserLive.Login
  end

  # Dev-only dashboard and mailbox
  if Application.compile_env(:trial_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TrialAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Admin routes
  scope "/admin", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user, :admin]

    live_session :admin,
      on_mount: [{TrialAppWeb.UserAuth, :require_authenticated}, {TrialAppWeb.UserAuth, :require_admin}] do
      live "/dashboard", AdminLive.Dashboard, :index
      live "/users", AdminLive.UserManagement, :index
      live "/users/:id/edit", AdminLive.UserManagement, :edit
      live "/organizations", AdminLive.OrganizationManagement, :index
      live "/departments", AdminLive.DepartmentManagement, :index
      live "/teams", AdminLive.TeamManagement, :index
      live "/employees", AdminLive.EmployeeManagement, :index
      live "/positions", AdminLive.PositionManagement, :index
    end
  end

  # Authenticated routes
  scope "/", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TrialAppWeb.UserAuth, :require_authenticated}] do
      live "/dashboard", DashboardLive, :index
      live "/organizations", OrganizationLive.Index, :index
      live "/organizations/:id", OrganizationLive.Index, :show
      live "/departments", DepartmentLive.Index, :index
      live "/teams", TeamLive.Index, :index
      live "/employees", EmployeeLive.Index, :index
      live "/positions", PositionLive.Index, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  # Public auth routes
  scope "/", TrialAppWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TrialAppWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/login", UserLive.Login, :new
    end

    post "/users/login", UserSessionController, :create
    delete "/users/logout", UserSessionController, :delete
  end

  # Permissions Policy header
  def put_custom_permissions_policy(conn, _opts) do
    permissions_policy =
      [
        "camera=()",
        "microphone=()",
        "geolocation=()",
        "payment=()",
        "usb=()",
        "magnetometer=()",
        "gyroscope=()",
        "accelerometer=()",
        "ambient-light-sensor=()",
        "autoplay=()",
        "fullscreen=(self)",
        "picture-in-picture=()"
      ]
      |> Enum.join(", ")

    put_resp_header(conn, "permissions-policy", permissions_policy)
  end
end
