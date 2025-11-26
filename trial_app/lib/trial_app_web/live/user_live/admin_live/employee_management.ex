defmodule TrialAppWeb.AdminLive.EmployeeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Repo}
  import TrialAppWeb.Live.Helpers.RoleSwitcher

  @impl true
  def handle_info({:switch_role, new_role}, socket), do: handle_role_switch(socket, new_role)

  @impl true
  def mount(_params, _session, socket) do
    # Fetch ALL users in the system with their employee assignments
    all_users = TrialApp.Accounts.list_users_with_assignments()

    # Separate assigned and unassigned users
    {assigned_users, unassigned_users} =
      Enum.split_with(all_users, fn user ->
        length(user.employees) > 0
      end)

    # Load departments for organizational grouping
    departments = load_departments()

    # Calculate statistics
    active_assigned_count =
      assigned_users
      |> Enum.filter(fn user ->
        Enum.any?(user.employees, & &1.is_active)
      end)
      |> length()

    teams_count =
      departments
      |> Enum.flat_map(& &1.teams)
      |> Enum.uniq_by(& &1.id)
      |> length()

    # Load organizations and programs from the system
    organizations = load_organizations()
    programs = load_programs()

    {:ok,
     socket
     |> assign(:page_title, "Employee Management")
     |> assign(:all_users, all_users)
     |> assign(:assigned_users, assigned_users)
     |> assign(:unassigned_users, unassigned_users)
     |> assign(:departments, departments)
     |> assign(:organizations, organizations)
     |> assign(:programs, programs)
     |> assign(:search, "")
     |> assign(:selected_department, "")
     |> assign(:view_mode, "department")
     |> assign(:expanded_departments, %{})
     |> assign(:total_users, length(all_users))
     |> assign(:assigned_count, length(assigned_users))
     |> assign(:unassigned_count, length(unassigned_users))
     |> assign(:active_count, active_assigned_count)
     |> assign(:teams_count, teams_count)
     # Create user modal assigns
     |> assign(:show_create_modal, false)
     |> assign(:user_form, %{})
     |> assign(:email_error, nil)
     |> assign(:creating_user, false)
     # Legacy assigns (can be removed later)
     |> assign(:selected_user_type, nil)
     |> assign(:attachee_form, %{})
     |> assign(:creating_attachee, false)
     # Assignment modal assigns
     |> assign(:show_assign_modal, false)
     |> assign(:user_to_assign, nil)
     |> assign(:selected_teams, [])}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    {:noreply, assign(socket, :search, String.trim(q))}
  end

  @impl true
  def handle_event("filter_department", %{"filter" => %{"department_id" => dept_id}}, socket) do
    {:noreply, assign(socket, :selected_department, dept_id)}
  end

  @impl true
  def handle_event("toggle_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  @impl true
  def handle_event("toggle_department", %{"id" => dept_id}, socket) do
    expanded_departments = socket.assigns.expanded_departments
    current_state = Map.get(expanded_departments, dept_id, true)
    updated_departments = Map.put(expanded_departments, dept_id, !current_state)

    {:noreply, assign(socket, :expanded_departments, updated_departments)}
  end

  @impl true
  def handle_event("view_employee", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/employees/#{id}")}
  end

  @impl true
  def handle_event("edit_employee", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/employees/#{id}/edit")}
  end

  @impl true
  def handle_event("delete_employee", %{"id" => id}, socket) do
    employee = Orgs.get_employee!(id)

    case Orgs.delete_employee(employee) do
      {:ok, _employee} ->
        # Reload all users and recalculate statistics
        all_users = TrialApp.Accounts.list_users_with_assignments()

        {assigned_users, unassigned_users} =
          Enum.split_with(all_users, fn user ->
            length(user.employees) > 0
          end)

        departments = load_departments()

        active_assigned_count =
          assigned_users
          |> Enum.filter(fn user ->
            Enum.any?(user.employees, & &1.is_active)
          end)
          |> length()

        teams_count =
          departments
          |> Enum.flat_map(& &1.teams)
          |> Enum.uniq_by(& &1.id)
          |> length()

        {:noreply,
         socket
         |> assign(:all_users, all_users)
         |> assign(:assigned_users, assigned_users)
         |> assign(:unassigned_users, unassigned_users)
         |> assign(:departments, departments)
         |> assign(:total_users, length(all_users))
         |> assign(:assigned_count, length(assigned_users))
         |> assign(:unassigned_count, length(unassigned_users))
         |> assign(:active_count, active_assigned_count)
         |> assign(:teams_count, teams_count)
         |> put_flash(:info, "Employee removed successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove employee")}
    end
  end

  # ========== NEW MODAL EVENT HANDLERS ==========

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:selected_user_type, nil)
     |> assign(:user_form, %{})
     |> assign(:email_error, nil)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:user_form, %{})
     |> assign(:selected_user_type, nil)
     |> assign(:email_error, nil)
     |> assign(:creating_user, false)
     # Also close assignment modal
     |> assign(:show_assign_modal, false)
     |> assign(:user_to_assign, nil)
     |> assign(:selected_teams, [])}
  end

  @impl true
  def handle_event("create_supervisor", %{"user" => user_params}, socket) do
    socket = assign(socket, :creating_user, true)

    # Generate secure password
    password = generate_secure_password()

    # 1. Create User
    user_data = %{
      email: user_params["email"],
      username: String.split(user_params["email"], "@") |> hd(),
      first_name: user_params["first_name"],
      password: password,
      password_confirmation: password,
      role: "supervisor",
      roles: ["supervisor"],
      active_role: "supervisor",
      status: "active"
    }

    case TrialApp.Accounts.register_user(user_data) do
      {:ok, user} ->
        # 2. Create Employee Record (link to Org/Dept)
        employee_attrs = %{
          name: user_params["first_name"],
          email: user.email,
          role: "manager",
          user_id: user.id,
          organization_id: user_params["organization_id"],
          department_id: user_params["department_id"],
          team_id: get_default_team_id(user_params["department_id"])
        }

        if employee_attrs.team_id do
          case TrialApp.Orgs.create_employee(employee_attrs) do
            {:ok, _employee} ->
              # Send email - FIXED: removed duplicate Mailer.deliver call
              TrialApp.Accounts.UserNotifier.deliver_user_credentials(user, password)

              handle_creation_success(
                socket,
                "✅ Supervisor created successfully! Credentials sent."
              )

            {:error, changeset} ->
              handle_creation_error(socket, changeset, user_params)
          end
        else
          # FIXED: removed duplicate Mailer.deliver call
          TrialApp.Accounts.UserNotifier.deliver_user_credentials(user, password)

          handle_creation_success(
            socket,
            "✅ Supervisor user created, but could not assign to department (no teams found)."
          )
        end

      {:error, changeset} ->
        handle_creation_error(socket, changeset, user_params)
    end
  end

  @impl true
  def handle_event("create_admin", %{"user" => user_params}, socket) do
    socket = assign(socket, :creating_user, true)

    password = generate_secure_password()

    user_data = %{
      email: user_params["email"],
      username: String.split(user_params["email"], "@") |> hd(),
      first_name: user_params["first_name"],
      password: password,
      password_confirmation: password,
      role: "admin",
      roles: ["admin"],
      active_role: "admin",
      status: "active"
    }

    case TrialApp.Accounts.register_user(user_data) do
      {:ok, user} ->
        # FIXED: removed duplicate Mailer.deliver call
        TrialApp.Accounts.UserNotifier.deliver_user_credentials(user, password)

        handle_creation_success(socket, "✅ Admin created successfully! Credentials sent.")

      {:error, changeset} ->
        handle_creation_error(socket, changeset, user_params)
    end
  end

  # Helper to reload data and update socket
  defp handle_creation_success(socket, message) do
    all_users = TrialApp.Accounts.list_users_with_assignments()

    {assigned_users, unassigned_users} =
      Enum.split_with(all_users, fn user ->
        length(user.employees) > 0
      end)

    departments = load_departments()

    {:noreply,
     socket
     |> assign(:all_users, all_users)
     |> assign(:assigned_users, assigned_users)
     |> assign(:unassigned_users, unassigned_users)
     |> assign(:departments, departments)
     |> assign(:total_users, length(all_users))
     |> assign(:assigned_count, length(assigned_users))
     |> assign(:unassigned_count, length(unassigned_users))
     |> assign(:show_create_modal, false)
     |> assign(:selected_user_type, nil)
     # Reset all form states
     |> assign(:user_form, %{})
     |> assign(:attachee_form, %{})
     |> assign(:supervisor_form, %{})
     |> assign(:admin_form, %{})
     |> assign(:email_error, nil)
     # Reset all loading states
     |> assign(:creating_user, false)
     |> assign(:creating_attachee, false)
     |> assign(:creating_supervisor, false)
     |> assign(:creating_admin, false)
     |> put_flash(:info, message)}
  end

  defp handle_creation_error(socket, changeset, params) do
    error_message = extract_error_message(changeset)

    {:noreply,
     socket
     |> assign(:creating_user, false)
     |> assign(:user_form, params)
     |> put_flash(:error, "Failed to create user: #{error_message}")}
  end

  defp get_default_team_id(department_id) do
    import Ecto.Query

    TrialApp.Orgs.Team
    |> where([t], t.department_id == ^department_id)
    |> limit(1)
    |> select([t], t.id)
    |> TrialApp.Repo.one()
  end

  @impl true
  def handle_event("toggle_team_selection", %{"team-id" => team_id}, socket) do
    team_id_int = String.to_integer(team_id)
    selected_teams = socket.assigns.selected_teams

    updated_teams =
      if team_id_int in selected_teams do
        List.delete(selected_teams, team_id_int)
      else
        [team_id_int | selected_teams]
      end

    {:noreply, assign(socket, :selected_teams, updated_teams)}
  end

  @impl true
  def handle_event("assign_user_to_teams", _params, socket) do
    user = socket.assigns.user_to_assign
    team_ids = socket.assigns.selected_teams

    if Enum.empty?(team_ids) do
      {:noreply, put_flash(socket, :error, "Please select at least one team")}
    else
      case TrialApp.Accounts.update_user_with_assignments(user, %{}, team_ids, %{}) do
        {:ok, _updated_user} ->
          # Reload all users and recalculate statistics
          all_users = TrialApp.Accounts.list_users_with_assignments()

          {assigned_users, unassigned_users} =
            Enum.split_with(all_users, fn user ->
              length(user.employees) > 0
            end)

          departments = load_departments()

          {:noreply,
           socket
           |> assign(:all_users, all_users)
           |> assign(:assigned_users, assigned_users)
           |> assign(:unassigned_users, unassigned_users)
           |> assign(:departments, departments)
           |> assign(:total_users, length(all_users))
           |> assign(:assigned_count, length(assigned_users))
           |> assign(:unassigned_count, length(unassigned_users))
           |> assign(:show_assign_modal, false)
           |> assign(:user_to_assign, nil)
           |> assign(:selected_teams, [])
           |> put_flash(:info, "User assigned to teams successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to assign user to teams")}
      end
    end
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    # Prevents modal from closing when clicking inside it
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_user_type", %{"type" => "employee"}, socket) do
    # Navigate to existing employee creation page
    {:noreply, push_navigate(socket, to: ~p"/admin/employees/new")}
  end

  @impl true
  def handle_event("select_user_type", %{"type" => "attachee"}, socket) do
    {:noreply, assign(socket, :selected_user_type, "attachee")}
  end

  @impl true
  def handle_event("select_user_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_user_type, type)}
  end

  @impl true
  def handle_event("create_attachee", %{"user" => user_params}, socket) do
    IO.inspect(user_params, label: "DEBUG: Create Attachee Params")
    # Set creating state to show loading spinner
    socket = assign(socket, :creating_attachee, true)

    # Validate email uniqueness
    case validate_unique_email(user_params["email"]) do
      {:error, message} ->
        IO.inspect(message, label: "DEBUG: Email Validation Failed")

        {:noreply,
         socket
         |> assign(:email_error, message)
         |> assign(:creating_attachee, false)
         |> assign(:attachee_form, user_params)}

      :ok ->
        # Generate secure password
        password = generate_secure_password()

        # 1. Create User
        user_data = %{
          email: user_params["email"],
          username: String.split(user_params["email"], "@") |> hd(),
          first_name: user_params["first_name"],
          password: password,
          password_confirmation: password,
          role: "user",
          roles: ["attachee"],
          status: "pending",
          must_change_password: true
        }

        case TrialApp.Accounts.register_user(user_data) do
          {:ok, user} ->
            IO.inspect(user, label: "DEBUG: User Created")
            # 2. Create Attachee Record
            attachee_data = %{
              user_id: user.id,
              position: "Attachee",
              organization_id: user_params["organization_id"],
              department_id: user_params["department_id"],
              status: "active",
              starts_on: Date.utc_today()
            }

            IO.inspect(attachee_data, label: "DEBUG: Attachee Data")

            case TrialApp.Eams.create_attachee(attachee_data) do
              {:ok, attachee} ->
                IO.inspect(attachee, label: "DEBUG: Attachee Created")
                # 3. Enroll in Program (if selected)
                if user_params["program_id"] && user_params["program_id"] != "" do
                  TrialApp.Eams.enroll_attachee_in_program(
                    attachee.id,
                    String.to_integer(user_params["program_id"])
                  )
                end

                # 4. Send Email
                TrialApp.Accounts.UserNotifier.deliver_user_credentials(user, password)

                handle_creation_success(
                  socket,
                  "✅ Success! Attachee #{user_params["first_name"]} has been created and login credentials sent to #{user.email}"
                )

              {:error, changeset} ->
                IO.inspect(changeset, label: "DEBUG: Attachee Creation Failed")
                error_message = extract_error_message(changeset)

                {:noreply,
                 socket
                 |> assign(:creating_attachee, false)
                 |> assign(:attachee_form, user_params)
                 |> put_flash(:error, "Failed to create attachee record: #{error_message}")}
            end

          {:error, changeset} ->
            IO.inspect(changeset, label: "DEBUG: User Creation Failed")
            error_message = extract_error_message(changeset)

            {:noreply,
             socket
             |> assign(:creating_attachee, false)
             |> assign(:attachee_form, user_params)
             |> put_flash(:error, "Failed to create user: #{error_message}")}
        end
    end
  end

  # ========== PRIVATE HELPER FUNCTIONS ==========

  defp load_departments do
    Orgs.list_departments()
    |> Repo.preload(employees: [:user, :team])
  end

  # Load organizations from the system
  defp load_organizations do
    Orgs.list_organizations()
  end

  # Load programs from the system
  defp load_programs do
    Orgs.list_programs()
  end

  # Validate if email is unique across employees and attachees
  defp validate_unique_email(email) do
    email = String.trim(email) |> String.downcase()

    cond do
      Orgs.email_exists_in_employees?(email) ->
        {:error, "This email is already registered as an employee"}

      Orgs.email_exists_in_attachees?(email) ->
        {:error, "This email is already registered as an attachee"}

      true ->
        :ok
    end
  end

  # Generate a secure random password
  defp generate_secure_password do
    length = 12
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%"

    1..length
    |> Enum.map(fn _ ->
      chars
      |> String.graphemes()
      |> Enum.random()
    end)
    |> Enum.join()
  end

  # Extract error message from changeset
  defp extract_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field} #{message}" end)
    |> Enum.join(", ")
  end

  # Helper: Check if employee matches search query
  defp matches_search?(_employee, ""), do: true
  defp matches_search?(_employee, nil), do: true

  defp matches_search?(employee, query) do
    q = String.downcase(query)

    searchable_fields = [
      employee.name || "",
      employee.email || "",
      employee.role || "",
      employee.position || "",
      (employee.team && employee.team.name) || ""
    ]

    Enum.any?(searchable_fields, fn val ->
      String.contains?(String.downcase(val), q)
    end)
  end

  # Helper: Check if department should be shown based on filters
  def should_show_department?(department, selected_dept, search) do
    dept_matches = selected_dept == "" || to_string(department.id) == selected_dept
    has_matching_employees = Enum.any?(department.employees, &matches_search?(&1, search))

    dept_matches && has_matching_employees
  end

  # Helper: Get filtered employees for list view
  def get_filtered_employees(departments, selected_dept, search) do
    departments
    |> Enum.filter(fn dept ->
      selected_dept == "" || to_string(dept.id) == selected_dept
    end)
    |> Enum.flat_map(fn dept ->
      dept.employees
      |> Enum.filter(&matches_search?(&1, search))
      |> Enum.map(&Map.put(&1, :department_name, dept.name))
    end)
  end

  # Helper: Get CSS classes for role badges
  def get_role_badge_class(role) do
    base_class = "px-3 py-1.5 text-sm rounded-full font-medium inline-block "

    role_name =
      cond do
        is_struct(role) -> role.name
        is_binary(role) -> role
        true -> ""
      end

    case String.downcase(role_name) do
      "admin" -> base_class <> "bg-purple-100 text-purple-700"
      "manager" -> base_class <> "bg-blue-100 text-blue-700"
      "lead" -> base_class <> "bg-indigo-100 text-indigo-700"
      "developer" -> base_class <> "bg-[#C1C1FF] text-[#3B3B98]"
      "designer" -> base_class <> "bg-pink-100 text-pink-700"
      "engineer" -> base_class <> "bg-cyan-100 text-cyan-700"
      "analyst" -> base_class <> "bg-green-100 text-green-700"
      "qa" -> base_class <> "bg-orange-100 text-orange-700"
      "support" -> base_class <> "bg-yellow-100 text-yellow-700"
      _ -> base_class <> "bg-gray-100 text-gray-700"
    end
  end

  # Helper: Format employee count text
  def format_employee_count(count) do
    case count do
      0 -> "No members"
      1 -> "1 member"
      n -> "#{n} members"
    end
  end

  # Helper: Get status badge class
  def get_status_badge_class(is_active) do
    if is_active do
      "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium bg-emerald-50 text-emerald-700"
    else
      "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full font-medium bg-gray-100 text-gray-500"
    end
  end

  # Helper: Get status dot class
  def get_status_dot_class(is_active) do
    if is_active do
      "w-1.5 h-1.5 rounded-full bg-emerald-500"
    else
      "w-1.5 h-1.5 rounded-full bg-gray-400"
    end
  end

  # Helper: Get employee initials
  def get_employee_initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end

  # Helper: Check if department is expanded
  def is_department_expanded?(expanded_departments, dept_id) do
    Map.get(expanded_departments, to_string(dept_id), true)
  end
end
