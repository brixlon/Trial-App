# lib/trial_app_web/router.ex
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

  scope "/", TrialAppWeb do
    pipe_through :browser

    # Keep Phoenix page at /home
    get "/home", PageController, :home
    live "/", UserLive.Login
  end

  # Other scopes may use custom stacks.
  # scope "/api", TrialAppWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trial_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TrialAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TrialAppWeb.UserAuth, :require_authenticated}] do
      live "/dashboard", DashboardLive, :index

      live "/organizations", OrganizationLive.Index, :index
      live "/organizations/new", OrganizationLive.Index, :new
      live "/organizations/:id/edit", OrganizationLive.Index, :edit
      live "/organizations/:id", OrganizationLive.Show, :show

      live "/departments", DepartmentLive.Index, :index
      live "/departments/new", DepartmentLive.Index, :new
      live "/departments/:id/edit", DepartmentLive.Index, :edit
      live "/departments/:id", DepartmentLive.Show, :show

      live "/teams", TeamLive.Index, :index
      live "/teams/new", TeamLive.Index, :new
      live "/teams/:id/edit", TeamLive.Index, :edit
      live "/teams/:id", TeamLive.Show, :show

      live "/employees", EmployeeLive.Index, :index
      live "/employees/new", EmployeeLive.Index, :new
      live "/employees/:id/edit", EmployeeLive.Index, :edit
      live "/employees/:id", EmployeeLive.Show, :show

      live "/positions", PositionLive.Index, :index
      live "/positions/new", PositionLive.Index, :new
      live "/positions/:id/edit", PositionLive.Index, :edit
      live "/positions/:id", PositionLive.Show, :show

      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TrialAppWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TrialAppWeb.UserAuth, :mount_current_scope}] do
      # Registration routes
      live "/users/register", UserLive.Registration, :new

      # Login routes - only keep one to avoid conflicts
      live "/users/login", UserLive.Login

      # Remove conflicting routes:
      # live "/users/log-in", UserLive.Login, :new
      # live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    # Keep these controller routes
    post "/users/login", UserSessionController, :create
    delete "/users/logout", UserSessionController, :delete
  end

  # Custom plug to override Permissions-Policy header with only supported features
  def put_custom_permissions_policy(conn, _opts) do
    # Override the Permissions-Policy header with only widely supported features
    # This removes experimental features that cause console errors
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
