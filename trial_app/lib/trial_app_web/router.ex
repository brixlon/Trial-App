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

  # ──────────────────────────────────────────────────────────────────────
  # PUBLIC (unauthenticated) ROUTES
  # ──────────────────────────────────────────────────────────────────────
  scope "/", TrialAppWeb do
    pipe_through [:browser]

    get "/home", PageController, :home

    # BOTH LiveView and Controller login routes
    live "/", UserLive.Login
    get "/users/login", UserSessionController, :login
    post "/users/login", UserSessionController, :create

    # Keep only necessary controller actions
    get "/users/login/direct", UserSessionController, :direct
    post "/users/update-password", UserSessionController, :update_password
    delete "/users/logout", UserSessionController, :delete

    # ──── PUBLIC LIVEVIEW ROUTES ────
    live_session :current_user,
      on_mount: [{TrialAppWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/force-reset/:token", ForcePasswordResetLive, :show
      live "/users/reset-password/:token", UserLive.ResetPassword, :show
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # AUTHENTICATED ROUTES (all roles)
  # ──────────────────────────────────────────────────────────────────────
  scope "/", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/uploads/task_submissions/:filename", DownloadController, :download_task_submission

    live_session :require_authenticated_user,
      on_mount: [{TrialAppWeb.UserAuth, :require_authenticated}] do

      live "/dashboard", DashboardLive, :index

      # ATTACHEE
      live "/attachee", AttacheeDashboardLive, :index
      live "/attachee/tasks", AttacheeTasksLive, :index
      live "/attachee/profile", AttacheeProfileLive, :show

      # ANNOUNCEMENTS - Available to admin, supervisor, and attachee roles
      live "/announcements", AnnouncementLive.Index, :index

      # GENERAL
      live "/organizations", OrganizationLive.Index, :index
      live "/organizations/:id", OrganizationLive.Index, :show
      live "/departments", DepartmentLive.Index, :index
      live "/teams", TeamLive.Index, :index
      live "/employees", EmployeeLive.Index, :index
      live "/positions", PositionLive.Index, :index

      # SETTINGS
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    # SUPERVISOR ROUTES (allows both supervisor AND admin)
    live_session :supervisor_or_admin,
      on_mount: [
        {TrialAppWeb.UserAuth, :require_authenticated},
        {TrialAppWeb.UserAuth, :require_supervisor_or_admin}
      ] do

      live "/supervisor/dashboard", SupervisorLive.Dashboard, :index
      live "/supervisor/team", SupervisorLive.Team, :index
      live "/supervisor/attachees", SupervisorLive.Attachees, :index
      live "/supervisor/tasks", SupervisorLive.Tasks, :index
      live "/supervisor/projects", SupervisorLive.Projects, :index
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # ADMIN-ONLY ROUTES
  # ──────────────────────────────────────────────────────────────────────
  scope "/admin", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user, :admin]

    live_session :admin,
      on_mount: [
        {TrialAppWeb.UserAuth, :require_authenticated},
        {TrialAppWeb.UserAuth, :require_admin}
      ] do

      live "/dashboard", AdminLive.Dashboard, :index
      live "/users", AdminLive.UserManagement, :index
      live "/users/:id/edit", AdminLive.UserManagement, :edit
      live "/positions", AdminLive.PositionManagement, :index
      live "/employees", AdminLive.EmployeeManagement, :index
      live "/employees/new", AdminLive.EmployeeForm, :new
      live "/pending-approvals", AdminLive.PendingApprovalLive, :index

      # EAMS SECTION
      live "/eams/programs", AdminLive.ProgramManagement, :index
      live "/eams/projects", AdminLive.ProjectManagement, :index
      live "/eams/tasks", AdminLive.TaskManagement, :index

      # ADMIN: View attachees in hierarchy (same as supervisor)
      live "/eams/attachees", SupervisorLive.Attachees, :index

      # ADMIN: Full CRUD management of attachees
      live "/eams/attachees/manage", AdminLive.AttacheeManagement, :index
    end
  end

  # ──────────────────────────────────────────────────────────────────────
  # PLUGS
  # ──────────────────────────────────────────────────────────────────────
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

  # ──────────────────────────────────────────────────────────────────────
  # DEV MAILBOX
  # ──────────────────────────────────────────────────────────────────────
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
