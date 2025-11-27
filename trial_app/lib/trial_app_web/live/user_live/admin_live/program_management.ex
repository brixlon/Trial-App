defmodule TrialAppWeb.AdminLive.ProgramManagement do
  use TrialAppWeb, :live_view
  require Logger

  alias TrialApp.{Eams, Orgs}

  # --------------------------------------------------------------------- #
  # MOUNT
  # --------------------------------------------------------------------- #
  @impl true
  def mount(_params, _session, socket) do
    Logger.info("ProgramManagement LiveView mounted")

    {:ok,
     socket
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})
     |> assign(:programs, list_programs_safe())
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_program, nil)
     |> assign(:viewing_program, nil)
     |> assign(:orgs, list_orgs_safe())
     |> assign(:departments, [])
     |> assign(:filter_departments, [])
     |> assign(:filter_programs, [])
     |> assign(:filtered_attachees, [])
     |> assign(:filter_org_id, "")
     |> assign(:filter_department_id, "")
     |> assign(:filter_program_id, "")
     |> assign(:form_data, %{
       "name" => "",
       "description" => "",
       "organization_id" => "",
       "department_id" => "",
       "code" => "",
       "starts_on" => "",
       "ends_on" => "",
       "status" => "active"
     })
     |> assign(:errors, %{})}
  end

  # --------------------------------------------------------------------- #
  # BASIC FORM EVENTS
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("new", _params, socket) do
    Logger.info("NEW BUTTON – opening form")
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_program, nil)
     |> assign(:form_data, %{
       "name" => "",
       "description" => "",
       "organization_id" => "",
       "department_id" => "",
       "code" => "",
       "starts_on" => "",
       "ends_on" => "",
       "status" => "active"
     })
     |> assign(:departments, [])
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_event("close", _params, socket) do
    Logger.info("CLOSE – resetting modals")
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:show_view_modal, false)
     |> assign(:editing_program, nil)
     |> assign(:viewing_program, nil)
     |> assign(:errors, %{})
     |> assign(:departments, [])
     |> assign(:form_data, %{
       "name" => "",
       "description" => "",
       "organization_id" => "",
       "department_id" => "",
       "code" => "",
       "starts_on" => "",
       "ends_on" => "",
       "status" => "active"
     })}
  end

  # --------------------------------------------------------------------- #
  # VIEW PROGRAM - Navigate to Program Show Page
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("view_program", %{"id" => id}, socket) do
    Logger.info("VIEW PROGRAM – navigating to program show page for ID: #{id}")
    {:noreply, push_navigate(socket, to: ~p"/admin/eams/programs/#{id}")}
  end

  # --------------------------------------------------------------------- #
  # EDIT PROGRAM
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("edit_program", %{"id" => id}, socket) do
    program = Eams.get_program!(id) |> TrialApp.Repo.preload([:organization, :department])

    form_data = %{
      "name" => program.name || "",
      "description" => program.description || "",
      "organization_id" => to_string(program.organization_id || ""),
      "department_id" => to_string(program.department_id || ""),
      "code" => program.code || "",
      "starts_on" => (if program.starts_on, do: Date.to_iso8601(program.starts_on), else: ""),
      "ends_on" => (if program.ends_on, do: Date.to_iso8601(program.ends_on), else: ""),
      "status" => program.status || "active"
    }

    departments = load_departments_safe(program.organization_id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:show_view_modal, false)
     |> assign(:editing_program, program)
     |> assign(:form_data, form_data)
     |> assign(:departments, departments)
     |> assign(:errors, %{})}
  end

  # --------------------------------------------------------------------- #
  # DELETE PROGRAM
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("delete_program", %{"id" => id}, socket) do
    program = Eams.get_program!(id)

    case Eams.delete_program(program) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:programs, list_programs_safe())
         |> put_flash(:info, "Program deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete program")}
    end
  end

  # --------------------------------------------------------------------- #
  # STOP PROPAGATION (for action buttons)
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  # --------------------------------------------------------------------- #
  # FORM UPDATE (org → dept + date validation)
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("update_form", %{"program" => params}, socket) do
    org_id = params["organization_id"] || ""
    org_int = safe_int(org_id)
    departments = if org_int, do: load_departments_safe(org_int), else: []

    # Validate dates
    errors = validate_dates(params, socket.assigns.errors)

    {:noreply,
     socket
     |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
     |> assign(:departments, departments)
     |> assign(:errors, errors)}
  end

  # --------------------------------------------------------------------- #
  # SAVE / UPDATE
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("save", %{"program" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"] || "",
      code: params["code"] || "",
      starts_on: parse_date(params["starts_on"]),
      ends_on: parse_date(params["ends_on"]),
      status: "active",
      organization_id: parse_int(params["organization_id"]),
      department_id: parse_int(params["department_id"])
    }

    result =
      if socket.assigns.editing_program do
        Eams.update_program(socket.assigns.editing_program, attrs)
      else
        Eams.create_program(attrs)
      end

    case result do
      {:ok, _program} ->
        Logger.info("Program #{if socket.assigns.editing_program, do: "updated", else: "created"} successfully")
        {:noreply,
         socket
         |> assign(:show_form, false)
         |> assign(:editing_program, nil)
         |> assign(:errors, %{})
         |> assign(:departments, [])
         |> assign(:form_data, %{
           "name" => "",
           "description" => "",
           "organization_id" => "",
           "department_id" => "",
           "code" => "",
           "starts_on" => "",
           "ends_on" => "",
           "status" => "active"
         })
         |> assign(:programs, list_programs_safe())
         |> put_flash(:info, "Program #{if socket.assigns.editing_program, do: "updated", else: "created"} successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> {field, msg} end)
          |> Enum.into(%{})

        {:noreply, assign(socket, :errors, errors)}
    end
  end

  # --------------------------------------------------------------------- #
  # FILTERING
  # --------------------------------------------------------------------- #
  @impl true
  def handle_event("filter_update", params, socket) do
    org_id = Map.get(params, "organization_id", "")
    dept_id = Map.get(params, "department_id", "")
    prog_id = Map.get(params, "program_id", "")

    filter_departments = load_departments(org_id)
    filter_programs = load_programs(dept_id)
    filtered_attachees = load_attachees(prog_id)

    {:noreply,
     socket
     |> assign(:filter_departments, filter_departments)
     |> assign(:filter_programs, filter_programs)
     |> assign(:filtered_attachees, filtered_attachees)
     |> assign(:filter_org_id, org_id)
     |> assign(:filter_department_id, dept_id)
     |> assign(:filter_program_id, prog_id)}
  end

  # --------------------------------------------------------------------- #
  # HELPERS
  # --------------------------------------------------------------------- #
  defp list_programs_safe do
    try do
      Eams.list_programs() |> TrialApp.Repo.preload([:organization, :department])
    rescue
      e ->
        Logger.error("Error listing programs: #{inspect(e)}")
        []
    end
  end

  defp list_orgs_safe do
    try do
      Orgs.list_all_organizations()
    rescue
      e ->
        Logger.error("Error listing organizations: #{inspect(e)}")
        []
    end
  end

  defp load_departments_safe(org_id) when is_integer(org_id) do
    try do
      Orgs.list_departments_by_org(org_id)
    rescue
      e ->
        Logger.error("Error loading departments: #{inspect(e)}")
        []
    end
  end

  defp load_departments(""), do: []
  defp load_departments(nil), do: []
  defp load_departments(id), do: load_departments_safe(String.to_integer(id))

  defp load_programs(""), do: []
  defp load_programs(nil), do: []
  defp load_programs(id) do
    try do
      Eams.list_programs_by_department(String.to_integer(id))
    rescue
      e ->
        Logger.error("Error loading programs: #{inspect(e)}")
        []
    end
  end

  defp load_attachees(""), do: []
  defp load_attachees(nil), do: []
  defp load_attachees(id) do
    try do
      Eams.list_attachees_by_program(String.to_integer(id), %{preloads: [:user]})
    rescue
      e ->
        Logger.error("Error loading attachees: #{inspect(e)}")
        []
    end
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)

  defp safe_int(""), do: nil
  defp safe_int(nil), do: nil
  defp safe_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil
  defp parse_date(<<y::4-binary, "-", m::2-binary, "-", d::2-binary>>) do
    with {year, _} <- Integer.parse(y),
         {month, _} <- Integer.parse(m),
         {day, _} <- Integer.parse(d),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _ -> nil
    end
  end
  defp parse_date(_), do: nil

  defp validate_dates(params, current_errors) do
    starts_on = params["starts_on"] || ""
    ends_on = params["ends_on"] || ""

    # Remove previous date errors
    errors = Map.drop(current_errors, [:starts_on, :ends_on])

    cond do
      # Both dates empty - no error
      starts_on == "" or ends_on == "" ->
        errors

      # Both dates present - validate
      true ->
        start_date = parse_date(starts_on)
        end_date = parse_date(ends_on)

        cond do
          is_nil(start_date) or is_nil(end_date) ->
            errors

          Date.compare(end_date, start_date) == :lt ->
            Map.put(errors, :ends_on, "End date must be on or after start date")

          true ->
            errors
        end
    end
  end
end
