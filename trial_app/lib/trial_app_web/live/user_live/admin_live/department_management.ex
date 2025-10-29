defmodule TrialAppWeb.AdminLive.DepartmentManagement do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:departments, [])
     |> assign(:show_form, false)
     |> assign(:form_data, %{name: "", description: ""})
     |> assign(:errors, %{})
     |> assign(:search_query, "")
     |> assign(:editing_id, nil)
     |> assign(:show_delete_modal, false)
     |> assign(:deleting_id, nil)}
  end

  def handle_event("new_department", _params, socket) do
    {:noreply,
     assign(socket,
       show_form: true,
       editing_id: nil,
       form_data: %{name: "", description: ""},
       errors: %{}
     )}
  end

  def handle_event("edit_department", %{"id" => id}, socket) do
    department = Enum.find(socket.assigns.departments, &(&1.id == String.to_integer(id)))

    if department do
      {:noreply,
       assign(socket,
         show_form: true,
         editing_id: String.to_integer(id),
         form_data: %{name: department.name, description: department.description || ""},
         errors: %{}
       )}
    else
      {:noreply, put_flash(socket, :error, "Department not found")}
    end
  end

  def handle_event("hide_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_form: false,
       editing_id: nil,
       form_data: %{name: "", description: ""},
       errors: %{}
     )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  def handle_event("update_form", params, socket) do
    form_data =
      case params do
        %{"name" => name, "description" => description} ->
          %{name: name, description: description}

        %{"value" => value} when is_binary(value) ->
          parse_form_data(value)

        _ ->
          socket.assigns.form_data
      end

    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("save_department", params, socket) do
    {name, description} =
      case params do
        %{"name" => n, "description" => d} ->
          {n, d}

        %{"value" => value} when is_binary(value) ->
          parse_form_values(value)

        _ ->
          {"", ""}
      end

    errors = %{}

    errors =
      if String.trim(name) == "",
        do: Map.put(errors, :name, "Department name is required"),
        else: errors

    if map_size(errors) == 0 do
      if socket.assigns.editing_id do
        # Update existing department
        updated_departments =
          Enum.map(socket.assigns.departments, fn dept ->
            if dept.id == socket.assigns.editing_id do
              %{dept | name: name, description: description}
            else
              dept
            end
          end)

        {:noreply,
         socket
         |> assign(
           show_form: false,
           editing_id: nil,
           form_data: %{name: "", description: ""},
           errors: %{}
         )
         |> assign(departments: updated_departments)
         |> put_flash(:info, "✅ Department '#{name}' updated successfully!")}
      else
        # Create new department
        new_department = %{
          id: :rand.uniform(100_000),
          name: name,
          description: description
        }

        {:noreply,
         socket
         |> assign(show_form: false, form_data: %{name: "", description: ""}, errors: %{})
         |> assign(departments: [new_department | socket.assigns.departments])
         |> put_flash(:info, "✅ Department '#{name}' created successfully!")}
      end
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       show_delete_modal: true,
       deleting_id: String.to_integer(id)
     )}
  end

  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_delete_modal: false,
       deleting_id: nil
     )}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    department_id = String.to_integer(id)
    department = Enum.find(socket.assigns.departments, &(&1.id == department_id))

    if department do
      updated_departments = Enum.reject(socket.assigns.departments, &(&1.id == department_id))

      {:noreply,
       socket
       |> assign(departments: updated_departments, show_delete_modal: false, deleting_id: nil)
       |> put_flash(:info, "🗑️ Department '#{department.name}' deleted successfully!")}
    else
      {:noreply,
       socket
       |> assign(show_delete_modal: false, deleting_id: nil)
       |> put_flash(:error, "Department not found")}
    end
  end

  defp parse_form_data(form_string) when is_binary(form_string) do
    form_string
    |> String.split("&")
    |> Enum.reduce(%{name: "", description: ""}, fn pair, acc ->
      case String.split(pair, "=") do
        ["name", value] -> Map.put(acc, :name, URI.decode(value))
        ["description", value] -> Map.put(acc, :description, URI.decode(value))
        _ -> acc
      end
    end)
  end

  defp parse_form_data(_), do: %{name: "", description: ""}

  defp parse_form_values(form_string) when is_binary(form_string) do
    data = parse_form_data(form_string)
    {data[:name] || "", data[:description] || ""}
  end

  defp parse_form_values(_), do: {"", ""}
end
