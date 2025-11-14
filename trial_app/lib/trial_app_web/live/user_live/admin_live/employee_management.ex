defmodule TrialAppWeb.AdminLive.EmployeeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Repo, Emails, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    departments = load_departments()
    employees = Orgs.list_employees()

    # Calculate statistics
    active_count = Enum.count(employees, & &1.is_active)
    teams_count =
      departments
      |> Enum.flat_map(& &1.teams)
      |> Enum.uniq_by(& &1.id)
      |> length()

    {:ok,
     socket
     |> assign(:page_title, "Employee Management")
     |> assign(:departments, departments)
     |> assign(:search, "")
     |> assign(:selected_department, nil)
     |> assign(:view_mode, "department")
     |> assign(:expanded_departments, %{})
     |> assign(:total_employees, length(employees))
     |> assign(:active_count, active_count)
     |> assign(:teams_count, teams_count)
     # Modal assigns for creating
     |> assign(:show_create_modal, false)
     |> assign(:selected_user_type, nil)
     |> assign(:attachee_form, init_attachee_form())
     |> assign(:available_users, [])
     |> assign(:email_error, nil)
     |> assign(:creating_attachee, false)
     # Modal assigns for editing
     |> assign(:show_modal, false)
     |> assign(:editing_employee, nil)
     |> assign(:changeset, nil)}
  end

  # Initialize empty attachee form
  defp init_attachee_form do
    %{
      user_id: nil,
      full_name: "",
      email: "",
      organization: "",
      department_id: nil,
      program: "",
      start_date: Date.utc_today() |> Date.to_string(),
      end_date: Date.utc_today() |> Date.add(90) |> Date.to_string(),
      errors: %{}
    }
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    {:noreply, assign(socket, :search, String.trim(q))}
  end

  @impl true
  def handle_event("filter_department", %{"filter" => %{"department_id" => dept_id}}, socket) do
    dept_id = if dept_id == "", do: nil, else: dept_id
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
  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, :search, "")}
  end

  @impl true
  def handle_event("clear_department_filter", _params, socket) do
    {:noreply, assign(socket, :selected_department, nil)}
  end

  @impl true
  def handle_event("clear_all_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:selected_department, nil)}
  end

  @impl true
  def handle_event("view_employee", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/employees/#{id}")}
  end

  @impl true
  def handle_event("edit_employee", %{"id" => id}, socket) do
    employee = Orgs.get_employee!(id) |> Repo.preload([:user, :team, :department, :organization])
    changeset = Orgs.change_employee(employee)

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_employee, employee)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save_employee", %{"employee" => employee_params}, socket) do
    employee = socket.assigns.editing_employee

    case Orgs.update_employee(employee, employee_params) do
      {:ok, _employee} ->
        {:noreply,
         socket
         |> assign(:show_modal, false)
         |> assign(:editing_employee, nil)
         |> assign(:changeset, nil)
         |> reload_statistics()
         |> put_flash(:info, "Employee updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:editing_employee, nil)
     |> assign(:changeset, nil)}
  end

  @impl true
  def handle_event("delete_employee", %{"id" => id}, socket) do
    employee = Orgs.get_employee!(id)

    case Orgs.permanently_delete_employee(employee) do
      {:ok, _employee} ->
        {:noreply,
         socket
         |> reload_statistics()
         |> put_flash(:info, "Employee permanently deleted")}

      {:error, changeset} ->
        error_msg = extract_error_message(changeset)
        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_event("toggle_employee_status", %{"id" => id}, socket) do
    employee = Orgs.get_employee!(id)

    case Orgs.toggle_employee_status(employee) do
      {:ok, updated_employee} ->
        status = if updated_employee.is_active, do: "activated", else: "deactivated"

        {:noreply,
         socket
         |> reload_statistics()
         |> put_flash(:info, "Employee #{status} successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update employee status")}
    end
  end

  # Modal Events for Creating
  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:selected_user_type, nil)
     |> assign(:attachee_form, init_attachee_form())
     |> assign(:email_error, nil)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:selected_user_type, nil)
     |> assign(:attachee_form, init_attachee_form())
     |> assign(:email_error, nil)
     |> assign(:creating_attachee, false)}
  end

  # Handle click propagation stop (no-op, just prevents event bubbling)
  @impl true
  def handle_event("stop_propagation", _params, socket) do
    # Prevents modal from closing when clicking inside it
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_user_type", %{"type" => type}, socket) do
    case type do
      "employee" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/employees/new")}

      "attachee" ->
        # Load available users when showing attachee form
        available_users = load_available_users()

        {:noreply,
         socket
         |> assign(:selected_user_type, type)
         |> assign(:available_users, available_users)}

      _ ->
        {:noreply, socket}
    end
  end

  # Handle user selection in attachee form
  @impl true
  def handle_event("attachee_user_selected", %{"attachee" => %{"user_id" => user_id}}, socket) do
    form = socket.assigns.attachee_form

    updated_form =
      if user_id == "new" do
        # Clear user-related fields for new user
        form
        |> Map.put(:user_id, "new")
        |> Map.put(:full_name, "")
        |> Map.put(:email, "")
      else
        # Load selected user data
        case Accounts.get_user(user_id) do
          nil ->
            form |> Map.put(:user_id, user_id)

          user ->
            form
            |> Map.put(:user_id, user_id)
            |> Map.put(:full_name, user.full_name || "")
            |> Map.put(:email, user.email || "")
        end
      end

    {:noreply,
     socket
     |> assign(:attachee_form, updated_form)
     |> assign(:email_error, nil)}
  end

  # Validate attachee form on change
  @impl true
  def handle_event("validate_attachee", %{"attachee" => params}, socket) do
    form = socket.assigns.attachee_form

    # Update form with new values
    updated_form = Map.merge(form, %{
      user_id: params["user_id"],
      full_name: params["full_name"] || "",
      email: params["email"] || "",
      organization: params["organization"] || "",
      department_id: params["department_id"],
      program: params["program"] || "",
      start_date: params["start_date"] || form.start_date,
      end_date: params["end_date"] || form.end_date
    })

    # Validate email if provided and creating new user
    email_error =
      if updated_form.user_id == "new" && updated_form.email != "" do
        case validate_unique_email(updated_form.email) do
          {:error, message} -> message
          :ok -> nil
        end
      else
        nil
      end

    # Basic field validations
    errors = validate_attachee_fields(updated_form)

    {:noreply,
     socket
     |> assign(:attachee_form, Map.put(updated_form, :errors, errors))
     |> assign(:email_error, email_error)}
  end

  @impl true
  def handle_event("create_attachee", %{"attachee" => params}, socket) do
    # Final validation
    case validate_attachee_submission(params) do
      {:error, message} ->
        {:noreply, assign(socket, :email_error, message)}

      :ok ->
        socket = assign(socket, :creating_attachee, true)
        password = generate_secure_password()

        # Convert string keys to atom keys and add password
        attachee_params =
          params
          |> atomize_keys()
          |> Map.put(:password, password)

        case Orgs.create_attachee(attachee_params) do
          {:ok, attachee} ->
            handle_attachee_creation_success(socket, attachee, password)

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:creating_attachee, false)
             |> assign(:email_error, extract_error_message(changeset))}
        end
    end
  end

  # Private helper functions

  # Convert string keys to atom keys for Ecto
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} -> {key, value}
    end)
  rescue
    ArgumentError ->
      # If atom doesn't exist, fall back to creating it
      Map.new(map, fn
        {key, value} when is_binary(key) -> {String.to_atom(key), value}
        {key, value} -> {key, value}
      end)
  end

  defp load_departments do
    Orgs.list_departments()
    |> Repo.preload(employees: [:user, :team])
  end

  # Load all users from database for selection
  defp load_available_users do
    # Load all users from the database
    # You can filter this later if needed (e.g., only active users, users without attachee records, etc.)
    Accounts.list_users()
  end

  # Validate attachee form fields
  defp validate_attachee_fields(form) do
    errors = %{}

    errors = if String.trim(form.full_name || "") == "",
      do: Map.put(errors, :full_name, "Full name is required"),
      else: errors

    errors = if String.trim(form.email || "") == "",
      do: Map.put(errors, :email, "Email is required"),
      else: errors

    errors = if String.trim(form.organization || "") == "",
      do: Map.put(errors, :organization, "Organization is required"),
      else: errors

    errors = if is_nil(form.department_id) || form.department_id == "",
      do: Map.put(errors, :department_id, "Department is required"),
      else: errors

    errors = if String.trim(form.program || "") == "",
      do: Map.put(errors, :program, "Program is required"),
      else: errors

    errors
  end

  # Validate attachee submission
  defp validate_attachee_submission(params) do
    email = params["email"] |> String.trim() |> String.downcase()

    cond do
      params["user_id"] == "new" && Orgs.email_exists_in_employees?(email) ->
        {:error, "This email is already registered as an employee"}

      params["user_id"] == "new" && Orgs.email_exists_in_attachees?(email) ->
        {:error, "This email is already registered as an attachee"}

      true ->
        :ok
    end
  end

  # Validate if email is unique
  defp validate_unique_email(email) do
    email = String.trim(email) |> String.downcase()

    cond do
      email == "" ->
        :ok

      Orgs.email_exists_in_employees?(email) ->
        {:error, "This email is already registered as an employee"}

      Orgs.email_exists_in_attachees?(email) ->
        {:error, "This email is already registered as an attachee"}

      true ->
        :ok
    end
  end

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

  defp extract_error_message(changeset) do
    case changeset.errors do
      [] ->
        "Failed to process request"
      errors ->
        errors
        |> Enum.map(fn {field, {message, _}} -> "#{field} #{message}" end)
        |> Enum.join(", ")
    end
  end

  defp handle_attachee_creation_success(socket, attachee, password) do
    case Emails.send_attachee_welcome_email(attachee, password) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_create_modal, false)
         |> assign(:selected_user_type, nil)
         |> assign(:attachee_form, init_attachee_form())
         |> assign(:creating_attachee, false)
         |> reload_statistics()
         |> put_flash(:info, "Attachee created and welcome email sent successfully!")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:show_create_modal, false)
         |> assign(:selected_user_type, nil)
         |> assign(:creating_attachee, false)
         |> reload_statistics()
         |> put_flash(:warning, "Attachee created but failed to send email. Please contact them manually.")}
    end
  end

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

  def should_show_department?(department, selected_dept, search) do
    dept_matches = is_nil(selected_dept) || selected_dept == "" || to_string(department.id) == selected_dept
    has_matching_employees = Enum.any?(department.employees, &matches_search?(&1, search))

    dept_matches && has_matching_employees
  end

  def get_filtered_employees(departments, selected_dept, search) do
    departments
    |> Enum.filter(fn dept ->
      is_nil(selected_dept) || selected_dept == "" || to_string(dept.id) == selected_dept
    end)
    |> Enum.flat_map(fn dept ->
      dept.employees
      |> Enum.filter(&matches_search?(&1, search))
      |> Enum.map(&Map.put(&1, :department_name, dept.name))
    end)
    |> Enum.sort_by(& &1.name)
  end

  def get_role_badge_class(role) do
    base_class = "px-3 py-1.5 text-xs rounded-full font-medium inline-block whitespace-nowrap "

    case String.downcase(role || "") do
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

  defp reload_statistics(socket) do
    departments = load_departments()
    employees = Orgs.list_employees()
    active_count = Enum.count(employees, & &1.is_active)

    teams_count =
      departments
      |> Enum.flat_map(& &1.teams)
      |> Enum.uniq_by(& &1.id)
      |> length()

    socket
    |> assign(:departments, departments)
    |> assign(:total_employees, length(employees))
    |> assign(:active_count, active_count)
    |> assign(:teams_count, teams_count)
  end
end
