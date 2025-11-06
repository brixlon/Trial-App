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

  pipeline :redirect_if_authenticated do
    plug :redirect_if_user_is_authenticated
  end

  pipeline :admin do
    plug :require_admin_user
  end

  pipeline :attachee do
    plug :require_attachee_user
  end

  pipeline :supervisor do
    plug :require_supervisor_user
  end

  # Public unauthenticated routes
  scope "/", TrialAppWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/home", PageController, :home

    # Controller routes
    get "/users/login", UserSessionController, :login
    post "/users/login", UserSessionController, :create
    get "/users/login/direct", UserSessionController, :direct
    post "/users/update-password", UserSessionController, :update_password

    live_session :redirect_if_user_is_authenticated,
      on_mount: [
        {TrialAppWeb.UserAuth, :mount_current_scope},
        {TrialAppWeb.UserAuth, :redirect_if_user_is_authenticated}
      ] do
      live "/", UserLive.Login
      live "/users/register", UserLive.Registration, :new
    end
  end

  # Logout route - should NOT redirect authenticated users
  scope "/", TrialAppWeb do
    pipe_through [:browser]

    delete "/users/logout", UserSessionController, :delete
  end

  # Authenticated routes (general)
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
      get  "/users/reset_password",          UserSessionController, :reset_password_form
      post "/users/reset_password",          UserSessionController, :reset_password
      get  "/users/force_password_change",   UserSessionController, :force_password_change_form
      post "/users/force_password_change",   UserSessionController, :force_password_change
    end
  end

  # Attachee routes
  scope "/attachee", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user, :attachee]

    live_session :attachee,
      on_mount: [
        {TrialAppWeb.UserAuth, :require_authenticated},
        {TrialAppWeb.UserAuth, :require_attachee}
      ] do
      live "/dashboard", AttacheeDashboardLive, :index
      live "/tasks/:id/submit", AttacheeTaskSubmitLive, :submit
      # Add more attachee-specific routes here
    end
  end

  # Supervisor routes (for future implementation)
  scope "/supervisor", TrialAppWeb do
    pipe_through [:browser, :require_authenticated_user, :supervisor]

    live_session :supervisor,
      on_mount: [
        {TrialAppWeb.UserAuth, :require_authenticated},
        {TrialAppWeb.UserAuth, :require_supervisor}
      ] do
      live "/dashboard", SupervisorLive.Dashboard, :index
      # Add more supervisor routes when ready
      # live "/attachees", SupervisorLive.Attachees, :index
      # live "/tasks", SupervisorLive.Tasks, :index
    end
  end

  # Admin routes
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

      # EAMS
      live "/eams/programs", AdminLive.ProgramManagement, :index
      live "/eams/projects", AdminLive.ProjectManagement, :index
      live "/eams/attachees", AdminLive.AttacheeManagement, :index
      live "/eams/tasks", AdminLive.TaskManagement, :index
      live "/eams/review-tasks", AdminLive.ReviewTasksLive, :index
    end
  end

  # Permissions Policy
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
