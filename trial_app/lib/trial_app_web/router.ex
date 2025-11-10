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

  pipeline :admin do
    plug :require_admin_user
  end

  # Public unauthenticated routes
  scope "/", TrialAppWeb do
    pipe_through [:browser]

    get "/home", PageController, :home
    live "/", UserLive.Login

    # Controller routes BEFORE LiveView to avoid conflicts
    get "/users/login", UserSessionController, :login
    post "/users/login", UserSessionController, :create
    get "/users/login/direct", UserSessionController, :direct
    post "/users/update-password", UserSessionController, :update_password
    delete "/users/logout", UserSessionController, :delete

    # Public LiveView routes
    live_session :current_user,
      on_mount: [{TrialAppWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
    end
  end

  # Authenticated routes (all roles)
  scope "/", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    # File download route (must be before live_session)
    get "/uploads/task_submissions/:filename", DownloadController, :download_task_submission

    live_session :require_authenticated_user,
      on_mount: [{TrialAppWeb.UserAuth, :require_authenticated}] do

      # General Dashboard
      live "/dashboard", DashboardLive, :index

      # ──────────────────────────────────────────────────────────────────────
      # ATTACHEE ROUTES
      # ──────────────────────────────────────────────────────────────────────
      live "/attachee", AttacheeDashboardLive, :index
      live "/attachee/tasks", AttacheeTasksLive, :index
      live "/attachee/profile", AttacheeProfileLive, :show

      # ──────────────────────────────────────────────────────────────────────
      # SUPERVISOR ROUTES
      # ──────────────────────────────────────────────────────────────────────
      live "/supervisor/dashboard", SupervisorLive.Dashboard, :index
      live "/supervisor/team", SupervisorLive.Team, :index
      live "/supervisor/attachees", SupervisorLive.Attachees, :index
      live "/supervisor/tasks", SupervisorLive.Tasks, :index

      # ──────────────────────────────────────────────────────────────────────
      # GENERAL USER ROUTES
      # ──────────────────────────────────────────────────────────────────────
      live "/organizations", OrganizationLive.Index, :index
      live "/organizations/:id", OrganizationLive.Index, :show
      live "/departments", DepartmentLive.Index, :index
      live "/teams", TeamLive.Index, :index
      live "/employees", EmployeeLive.Index, :index
      live "/positions", PositionLive.Index, :index

      # Settings
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end
  end

  # Admin-only routes
  scope "/admin", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user, :admin]

    live_session :admin,
      on_mount: [
        {TrialAppWeb.UserAuth, :require_authenticated},
        {TrialAppWeb.UserAuth, :require_admin}
      ] do

      live "/dashboard", AdminLive.Dashboard, :index

      # User & HR Management
      live "/users", AdminLive.UserManagement, :index
      live "/users/:id/edit", AdminLive.UserManagement, :edit
      live "/positions", AdminLive.PositionManagement, :index
      live "/employees", AdminLive.EmployeeManagement, :index
      live "/employees/new", AdminLive.EmployeeForm, :new
      live "/pending-approvals", AdminLive.PendingApprovalLive, :index

      # EAMS Admin
      live "/eams/programs", AdminLive.ProgramManagement, :index
      live "/eams/projects", AdminLive.ProjectManagement, :index
      live "/eams/attachees", AdminLive.AttacheeManagement, :index
      live "/eams/tasks", AdminLive.TaskManagement, :index
    end
  end

  # Permissions-Policy header
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
