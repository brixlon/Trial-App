defmodule TrialAppWeb.AdminLive.AttacheeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Repo, Eams, Orgs, Accounts}
  alias TrialApp.Eams.Attachee

  # Mount initial assigns
  def mount(_params, _session, socket) do
    organizations = Orgs.list_organizations()
    users = Accounts.list_users()
    attachees = list_attachees_with_auto_status()
    changeset = Attachee.changeset(%Attachee{}, %{})

    socket =
      socket
      |> assign(:organizations, organizations)
      |> assign(:users, users)
      |> assign(:attachees, attachees)
      |> assign(:form, to_form(changeset))
      |> assign(:show_modal, false)
      |> assign(:editing_attachee, nil)
      |> assign(:departments, [])
      |> assign(:programs, [])
      |> assign(:filter_status, "all")
      |> assign(:search_query, "")
      |> assign(:upcoming_completions, get_upcoming_completions(attachees))
      |> assign(:show_progress_modal, false)
      |> assign(:selected_attachee_for_progress, nil)
      |> assign(:milestones, [])

    # Schedule periodic status checks (every hour)
    if connected?(socket) do
      Process.send_after(self(), :update_statuses, :timer.hours(1))
    end

    {:ok, socket}
  end

  # Handle periodic status updates
  def handle_info(:update_statuses, socket) do
    attachees = list_attachees_with_auto_status()

    # Schedule next update
    Process.send_after(self(), :update_statuses, :timer.hours(1))

    {:noreply,
     socket
     |> assign(:attachees, attachees)
     |> assign(:upcoming_completions, get_upcoming_completions(attachees))}
  end

  # Open modal for new attachee
  def handle_event("open_modal", _params, socket) do
    changeset = Attachee.changeset(%Attachee{}, %{})

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:form, to_form(changeset))
     |> assign(:editing_attachee, nil)
     |> assign(:departments, [])
     |> assign(:programs, [])}
  end

  # Close modal
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:editing_attachee, nil)}
  end

  # Prevent modal from closing when clicking inside
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  # Handle filter
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  # Edit attachee - FIXED VERSION
  def handle_event("edit_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id) |> Repo.preload([:user, :organization, :department, :programs])

    # Load departments for the attachee's organization
    departments = if attachee.organization_id do
      Orgs.list_departments_by_org(attachee.organization_id)
    else
      []
    end

    # Load programs for the attachee's department
    programs = if attachee.department_id do
      Eams.list_programs_by_department(attachee.department_id)
    else
      []
    end

    # Get the first program ID if attachee has programs
    program_id = if Ecto.assoc_loaded?(attachee.programs) and attachee.programs != [] do
      hd(attachee.programs).id
    else
      nil
    end

    # Create changeset with all the data including program_id
    changeset_data = %{
      "user_id" => attachee.user_id,
      "organization_id" => attachee.organization_id,
      "department_id" => attachee.department_id,
      "program_id" => program_id,
      "starts_on" => attachee.starts_on,
      "ends_on" => attachee.ends_on,
      "status" => attachee.status
    }

    changeset = Attachee.changeset(attachee, changeset_data)

    {:noreply,
     socket
     |> assign(:editing_attachee, attachee)
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, programs)
     |> assign(:show_modal, true)}
  end

  # Delete attachee
  def handle_event("delete_attachee", %{"id" => id}, socket) do
    attachee = Eams.get_attachee!(id)

    case Eams.delete_attachee(attachee) do
      {:ok, _} ->
        updated_attachees = list_attachees_with_auto_status()
        {:noreply,
         socket
         |> assign(:attachees, updated_attachees)
         |> put_flash(:info, "Attachee deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete attachee")}
    end
  end

  # Validate form on change with auto-calculation
  def handle_event("validate", %{"attachee" => params}, socket) do
    attachee = socket.assigns.editing_attachee || %Attachee{}

    # Auto-calculate end date (3 months from start)
    params = auto_calculate_end_date(params)

    changeset =
      attachee
      |> Attachee.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  # Handle organization selection change
  def handle_event("organization_changed", %{"attachee" => params}, socket) do
    org_id = safe_int(params["organization_id"])

    departments = if org_id do
      Orgs.list_departments_by_org(org_id)
    else
      []
    end

    # Reset department and program when organization changes
    params = params
      |> Map.put("department_id", "")
      |> Map.put("program_id", "")
      |> auto_calculate_end_date()

    attachee = socket.assigns.editing_attachee || %Attachee{}
    changeset =
      attachee
      |> Attachee.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:departments, departments)
     |> assign(:programs, [])}
  end

  # Handle department selection change
  def handle_event("department_changed", %{"attachee" => params}, socket) do
    dept_id = safe_int(params["department_id"])

    programs = if dept_id do
      Eams.list_programs_by_department(dept_id)
    else
      []
    end

    # Reset program when department changes
    params = params
      |> Map.put("program_id", "")
      |> auto_calculate_end_date()

    attachee = socket.assigns.editing_attachee || %Attachee{}
    changeset =
      attachee
      |> Attachee.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:programs, programs)}
  end

  # Save new or update attachee with auto-calculations
  def handle_event("save", %{"attachee" => params}, socket) do
    # Auto-calculate end date (3 months from start)
    params = auto_calculate_end_date(params)

    # Convert string IDs to integers and parse dates
    attrs = %{
      user_id: safe_int(params["user_id"]),
      organization_id: safe_int(params["organization_id"]),
      department_id: safe_int(params["department_id"]),
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: params["status"] || "active"
    }

    program_id = safe_int(params["program_id"])

    result = if socket.assigns.editing_attachee do
      Eams.update_attachee(socket.assigns.editing_attachee, attrs)
    else
      Eams.create_attachee(attrs)
    end

    case result do
      {:ok, attachee} ->
        # Enroll in program (if selected)
        if program_id do
          Eams.enroll_attachee_in_program(attachee.id, program_id)
        end

        # Reload attachees list with auto-status
        updated_attachees = list_attachees_with_auto_status()

        # Reset form
        changeset = Attachee.changeset(%Attachee{}, %{})

        {:noreply,
         socket
         |> assign(:show_modal, false)
         |> assign(:editing_attachee, nil)
         |> assign(:form, to_form(changeset))
         |> assign(:attachees, updated_attachees)
         |> assign(:departments, [])
         |> assign(:programs, [])
         |> assign(:upcoming_completions, get_upcoming_completions(updated_attachees))
         |> put_flash(:info, "Attachee #{if socket.assigns.editing_attachee, do: "updated", else: "created"} successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Failed to save attachee. Please check the errors.")}
    end
  end

  # Auto-calculate end date (3 months/90 days from start date)
  defp auto_calculate_end_date(%{"starts_on" => starts_on} = params) when starts_on not in [nil, ""] do
    start_date = parse_date(starts_on)

    if start_date do
      # Calculate 3 months (90 days) from start date
      end_date = Date.add(start_date, 90)
      Map.put(params, "ends_on", Date.to_iso8601(end_date))
    else
      params
    end
  end
  defp auto_calculate_end_date(params), do: params

  # Fetch attachees and update their status based on dates
  defp list_attachees_with_auto_status do
    attachees = Eams.list_attachees(%{preloads: [:user, :organization, :department, :programs]})
    today = Date.utc_today()

    Enum.map(attachees, fn attachee ->
      auto_status = calculate_attachee_status(attachee, today)

      # Update in database if status changed
      if auto_status != attachee.status do
        case Eams.update_attachee(attachee, %{status: auto_status}) do
          {:ok, updated_attachee} ->
            updated_attachee |> Repo.preload([:user, :organization, :department, :programs])
          {:error, _} ->
            attachee
        end
      else
        attachee
      end
    end)
  end

  defp calculate_attachee_status(attachee, today) do
    cond do
      is_nil(attachee.starts_on) ->
        attachee.status

      is_nil(attachee.ends_on) ->
        attachee.status

      Date.compare(today, attachee.ends_on) == :gt ->
        "completed"

      Date.compare(today, attachee.starts_on) == :lt ->
        "inactive"

      true ->
        "active"
    end
  end

  # Helpers
  defp safe_int(value) when is_binary(value) and value != "", do: String.to_integer(value)
  defp safe_int(value) when is_integer(value), do: value
  defp safe_int(_), do: nil

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end
  defp parse_date(%Date{} = date), do: date
  defp parse_date(_), do: nil

  defp user_display(user), do: "#{user.username} (#{user.email})"

  defp department_options([]), do: [{"Select organization first", ""}]
  defp department_options(departments) do
    [{"Select Department", ""} | Enum.map(departments, &{&1.name, &1.id})]
  end

  defp program_options([]), do: [{"Select department first", ""}]
  defp program_options(programs) do
    [{"Select Program (Optional)", ""} | Enum.map(programs, &{&1.name, &1.id})]
  end

  defp status_color("active"), do: "bg-green-100 text-green-800"
  defp status_color("inactive"), do: "bg-amber-100 text-amber-800"
  defp status_color("completed"), do: "bg-blue-100 text-blue-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp filtered_attachees(attachees, "all"), do: attachees
  defp filtered_attachees(attachees, status), do: Enum.filter(attachees, &(&1.status == status))

  defp count_by_status(attachees, "all"), do: length(attachees)
  defp count_by_status(attachees, status), do: Enum.count(attachees, &(&1.status == status))

  defp filtered_attachees(attachees, "all"), do: attachees
  defp filtered_attachees(attachees, status), do: Enum.filter(attachees, &(&1.status == status))

  # Get attachees completing soon
  defp get_upcoming_completions(attachees) do
    today = Date.utc_today()
    thirty_days = Date.add(today, 30)

    attachees
    |> Enum.filter(fn attachee ->
      attachee.ends_on != nil and
      attachee.status == "active" and
      Date.compare(attachee.ends_on, today) in [:gt, :eq] and
      Date.compare(attachee.ends_on, thirty_days) in [:lt, :eq]
    end)
    |> Enum.sort_by(& &1.ends_on, Date)
  end

  # Search functionality
  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  # Export to CSV
  @impl true
  def handle_event("export_csv", _params, socket) do
    attachees = filtered_and_searched_attachees(
      socket.assigns.attachees,
      socket.assigns.filter_status,
      socket.assigns.search_query
    )

    csv_content = generate_csv(attachees)

    # In a real implementation, you'd send this as a download
    # For now, we'll just show a flash message
    {:noreply, put_flash(socket, :info, "CSV export ready with #{length(attachees)} records")}
  end

  # Send email notification
  @impl true
  def handle_event("send_notification", %{"id" => id, "type" => type}, socket) do
    attachee = Enum.find(socket.assigns.attachees, &(&1.id == String.to_integer(id)))

    # In a real implementation, you'd call your email service here
    # For now, we'll just simulate it
    message = case type do
      "completion_reminder" -> "Completion reminder sent to #{attachee.user.email}"
      "status_update" -> "Status update notification sent"
      _ -> "Notification sent"
    end

    {:noreply, put_flash(socket, :info, message)}
  end

  # Open progress tracking modal
  @impl true
  def handle_event("open_progress_modal", %{"id" => id}, socket) do
    attachee = Enum.find(socket.assigns.attachees, &(&1.id == String.to_integer(id)))
    milestones = get_milestones_for_attachee(attachee)

    {:noreply,
     socket
     |> assign(:show_progress_modal, true)
     |> assign(:selected_attachee_for_progress, attachee)
     |> assign(:milestones, milestones)}
  end

  @impl true
  def handle_event("close_progress_modal", _params, socket) do
    {:noreply, assign(socket, :show_progress_modal, false)}
  end

  # Toggle milestone completion
  @impl true
  def handle_event("toggle_milestone", %{"milestone_id" => milestone_id}, socket) do
    milestones = socket.assigns.milestones

    updated_milestones = Enum.map(milestones, fn milestone ->
      if milestone.id == milestone_id do
        %{milestone | completed: !milestone.completed}
      else
        milestone
      end
    end)

    # In a real implementation, you'd save this to the database
    {:noreply, assign(socket, :milestones, updated_milestones)}
  end

  # Helper to get milestones for an attachee
  defp get_milestones_for_attachee(attachee) do
    # In a real implementation, you'd fetch from database
    # For now, calculate based on attachment dates
    if attachee.starts_on do
      start_date = attachee.starts_on
      today = Date.utc_today()

      # Calculate progress based on dates
      orientation_date = Date.add(start_date, 5)
      intro_date = Date.add(start_date, 7)
      first_project_date = Date.add(start_date, 15)
      midterm_date = Date.add(start_date, 45)
      final_project_date = Date.add(start_date, 80)
      final_eval_date = Date.add(start_date, 85)

      [
        %{
          id: "1",
          title: "Orientation Completed",
          completed: Date.compare(today, orientation_date) != :lt,
          due_date: orientation_date
        },
        %{
          id: "2",
          title: "Department Introduction",
          completed: Date.compare(today, intro_date) != :lt,
          due_date: intro_date
        },
        %{
          id: "3",
          title: "First Project Assignment",
          completed: Date.compare(today, first_project_date) != :lt,
          due_date: first_project_date
        },
        %{
          id: "4",
          title: "Mid-term Evaluation",
          completed: Date.compare(today, midterm_date) != :lt,
          due_date: midterm_date
        },
        %{
          id: "5",
          title: "Final Project Submission",
          completed: Date.compare(today, final_project_date) != :lt,
          due_date: final_project_date
        },
        %{
          id: "6",
          title: "Final Evaluation",
          completed: Date.compare(today, final_eval_date) != :lt,
          due_date: final_eval_date
        },
      ]
    else
      # Default milestones if no start date
      [
        %{id: "1", title: "Orientation Completed", completed: false, due_date: Date.utc_today()},
        %{id: "2", title: "Department Introduction", completed: false, due_date: Date.utc_today()},
        %{id: "3", title: "First Project Assignment", completed: false, due_date: Date.utc_today()},
        %{id: "4", title: "Mid-term Evaluation", completed: false, due_date: Date.utc_today()},
        %{id: "5", title: "Final Project Submission", completed: false, due_date: Date.utc_today()},
        %{id: "6", title: "Final Evaluation", completed: false, due_date: Date.utc_today()},
      ]
    end
  end

  # Calculate progress percentage for an attachee
  defp calculate_progress_percentage(attachee) do
    milestones = get_milestones_for_attachee(attachee)
    total = length(milestones)

    if total > 0 do
      completed = Enum.count(milestones, & &1.completed)
      trunc(completed / total * 100)
    else
      0
    end
  end

  # Generate CSV content
  defp generate_csv(attachees) do
    headers = "Name,Email,Organization,Department,Start Date,End Date,Status\n"

    rows = Enum.map(attachees, fn attachee ->
      [
        attachee.user.username,
        attachee.user.email,
        attachee.organization.name,
        attachee.department.name,
        attachee.starts_on,
        attachee.ends_on,
        attachee.status
      ]
      |> Enum.join(",")
    end)
    |> Enum.join("\n")

    headers <> rows
  end

  # Combined filter and search
  defp filtered_and_searched_attachees(attachees, filter_status, search_query) do
    attachees
    |> filtered_attachees(filter_status)
    |> search_attachees(search_query)
  end

  defp search_attachees(attachees, ""), do: attachees
  defp search_attachees(attachees, query) do
    query_lower = String.downcase(query)

    Enum.filter(attachees, fn attachee ->
      String.contains?(String.downcase(attachee.user.username), query_lower) or
      String.contains?(String.downcase(attachee.user.email), query_lower) or
      String.contains?(String.downcase(attachee.organization.name), query_lower) or
      String.contains?(String.downcase(attachee.department.name), query_lower)
    end)
  end
end
