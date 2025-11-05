defmodule TrialAppWeb.AdminLive.ProgramManagement do
  use TrialAppWeb, :live_view
  require Logger

  alias TrialApp.{Eams, Orgs}

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("ProgramManagement LiveView mounted")

    {:ok,
     socket
     |> assign(:current_scope, socket.assigns[:current_scope] || %{})
     |> assign(:programs, list_programs_safe())
     |> assign(:show_form, false)
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

  @impl true
  @impl true
  
  # === Event Handlers ===

  @impl true
  def handle_event("new", _params, socket) do
    Logger.info("NEW BUTTON CLICKED - Opening form")
    {:noreply, assign(socket, show_form: true)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    Logger.info("CLOSE BUTTON CLICKED - Closing form")
    {:noreply,
     socket
     |> assign(show_form: false)
     |> assign(errors: %{})
     |> assign(departments: [])
     |> assign(form_data: %{
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

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_form", %{"program" => params}, socket) do
    Logger.info("UPDATE FORM: #{inspect(params)}")
    org_id = params["organization_id"] || ""
    org_int = safe_int(org_id)
    departments = if org_int, do: load_departments_safe(org_int), else: []

    # Clear date errors when dates change
    new_errors =
      socket.assigns.errors
      |> Map.delete(:starts_on)
      |> Map.delete(:ends_on)

    {:noreply,
     socket
     |> assign(:form_data, Map.merge(socket.assigns.form_data, params))
     |> assign(:departments, departments)
     |> assign(:errors, new_errors)}
  end

  @impl true
  def handle_event("update_form", params, socket) do
    Logger.warning("UPDATE FORM received unexpected params: #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"program" => params}, socket) do
    Logger.info("SAVE PROGRAM: #{inspect(params)}")

    starts_on = parse_date(params["starts_on"])
    ends_on = parse_date(params["ends_on"])

    Logger.info("Parsed dates - starts_on: #{inspect(starts_on)}, ends_on: #{inspect(ends_on)}")

    # Validate dates before attempting to create
    case validate_dates(starts_on, ends_on) do
      :ok ->
        attrs = %{
          name: params["name"],
          description: params["description"] || "",
          code: params["code"] || "",
          starts_on: starts_on,
          ends_on: ends_on,
          status: "active",
          organization_id: parse_int(params["organization_id"]),
          department_id: parse_int(params["department_id"])
        }

        case Eams.create_program(attrs) do
          {:ok, _program} ->
            Logger.info("Program created successfully")
            {:noreply,
             socket
             |> assign(:show_form, false)
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
             |> put_flash(:info, "Program created successfully")}

          {:error, %Ecto.Changeset{} = changeset} ->
            Logger.error("Program creation failed: #{inspect(changeset.errors)}")
            errors =
              changeset.errors
              |> Enum.map(fn {field, {msg, _}} -> {field, msg} end)
              |> Enum.into(%{})

            {:noreply, assign(socket, :errors, errors)}
        end

      {:error, error_field, error_message} ->
        Logger.warning("Date validation failed: #{error_message}")
        errors = Map.put(socket.assigns.errors, error_field, error_message)
        {:noreply, assign(socket, :errors, errors)}
    end
  end

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

  # === Date Validation ===

  defp validate_dates(nil, nil), do: :ok
  defp validate_dates(nil, _ends_on), do: :ok
  defp validate_dates(_starts_on, nil), do: :ok

  defp validate_dates(starts_on, ends_on) do
    case Date.compare(starts_on, ends_on) do
      :gt -> {:error, :ends_on, "End date must be on or after start date"}
      _ -> :ok
    end
  end

  # === Helper Functions with error handling ===

  defp list_programs_safe do
    try do
      Eams.list_programs()
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

  defp load_departments_safe(org_id) do
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

  # Handle YYYY-MM-DD format (standard HTML date input)
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

  # Handle DD/MM/YYYY format
  defp parse_date(<<d::2-binary, "/", m::2-binary, "/", y::4-binary>>) do
    with {day, _} <- Integer.parse(d),
         {month, _} <- Integer.parse(m),
         {year, _} <- Integer.parse(y),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _ -> nil
    end
  end

  # Handle MM/DD/YYYY format
  defp parse_date(<<m::2-binary, "/", d::2-binary, "/", y::4-binary>> = str) do
    # Try MM/DD/YYYY first
    with {month, _} <- Integer.parse(m),
         {day, _} <- Integer.parse(d),
         {year, _} <- Integer.parse(y),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _ ->
        # If that fails, maybe it was DD/MM/YYYY
        Logger.warning("Could not parse date: #{str}")
        nil
    end
  end

  defp parse_date(val) do
    Logger.warning("Unexpected date format: #{inspect(val)}")
    nil
  end
end
