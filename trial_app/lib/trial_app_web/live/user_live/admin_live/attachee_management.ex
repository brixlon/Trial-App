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

    {:noreply, assign(socket, :attachees, attachees)}
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
      status: calculate_status_from_dates(params)
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

  # Calculate status based on dates
  defp calculate_status_from_dates(%{"starts_on" => starts_on, "ends_on" => ends_on, "status" => manual_status})
       when manual_status not in [nil, ""] do
    # If user manually set a status while editing, use it
    manual_status
  end
  defp calculate_status_from_dates(%{"starts_on" => starts_on, "ends_on" => ends_on}) do
    today = Date.utc_today()
    start_date = parse_date(starts_on)
    end_date = parse_date(ends_on)

    cond do
      is_nil(start_date) -> "inactive"
      is_nil(end_date) -> "active"
      Date.compare(today, end_date) == :gt -> "completed"
      Date.compare(today, start_date) == :lt -> "inactive"
      true -> "active"
    end
  end
  defp calculate_status_from_dates(_), do: "active"

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
end
