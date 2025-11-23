defmodule TrialAppWeb.AdminLive.RoleManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Role Management")
     |> assign(:show_form, false)
     |> assign(:editing_role, nil)
     |> assign(:form_data, %{})
     |> assign(:selected_permissions, [])
     |> load_data()}
  end

  @impl true
  def handle_event("new_role", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_role, nil)
     |> assign(:form_data, %{name: "", description: ""})
     |> assign(:selected_permissions, [])}
  end

  @impl true
  def handle_event("edit_role", %{"id" => id}, socket) do
    role = Accounts.get_role!(id)
    permission_ids = Enum.map(role.permissions, & &1.id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_role, role)
     |> assign(:form_data, %{name: role.name, description: role.description || ""})
     |> assign(:selected_permissions, permission_ids)}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:editing_role, nil)}
  end

  @impl true
  def handle_event("update_form", %{"name" => name, "description" => description}, socket) do
    {:noreply, assign(socket, :form_data, %{name: name, description: description})}
  end

  @impl true
  def handle_event("toggle_permission", %{"id" => id}, socket) do
    permission_id = String.to_integer(id)
    selected = socket.assigns.selected_permissions

    new_selected =
      if permission_id in selected do
        List.delete(selected, permission_id)
      else
        [permission_id | selected]
      end

    {:noreply, assign(socket, :selected_permissions, new_selected)}
  end

  @impl true
  def handle_event("save_role", _params, socket) do
    %{form_data: form_data, editing_role: editing_role, selected_permissions: permission_ids} =
      socket.assigns

    result =
      if editing_role do
        with {:ok, role} <- Accounts.update_role(editing_role, form_data),
             {:ok, _role} <- Accounts.assign_permissions_to_role(role, permission_ids) do
          {:ok, role}
        end
      else
        with {:ok, role} <- Accounts.create_role(form_data),
             {:ok, _role} <- Accounts.assign_permissions_to_role(role, permission_ids) do
          {:ok, role}
        end
      end

    case result do
      {:ok, _role} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role saved successfully")
         |> assign(:show_form, false)
         |> load_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save role")}
    end
  end

  @impl true
  def handle_event("delete_role", %{"id" => id}, socket) do
    role = Accounts.get_role!(id)

    if role.is_system_role do
      {:noreply, put_flash(socket, :error, "Cannot delete system roles")}
    else
      case Accounts.delete_role(role) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Role deleted successfully")
           |> load_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete role")}
      end
    end
  end

  defp load_data(socket) do
    roles = Accounts.list_roles()
    permissions = Accounts.list_permissions()
    grouped_permissions = Accounts.Permission.group_by_category(permissions)

    socket
    |> assign(:roles, roles)
    |> assign(:permissions, permissions)
    |> assign(:grouped_permissions, grouped_permissions)
  end
end
