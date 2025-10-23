defmodule TrialAppWeb.DepartmentLive.Form do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations
  alias TrialApp.Organizations.Department

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage department records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="department-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Department</.button>
          <.button navigate={return_path(@current_scope, @return_to, @department)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    department = Organizations.get_department!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Department")
    |> assign(:department, department)
    |> assign(:form, to_form(Organizations.change_department(socket.assigns.current_scope, department)))
  end

  defp apply_action(socket, :new, _params) do
    department = %Department{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Department")
    |> assign(:department, department)
    |> assign(:form, to_form(Organizations.change_department(socket.assigns.current_scope, department)))
  end

  @impl true
  def handle_event("validate", %{"department" => department_params}, socket) do
    changeset = Organizations.change_department(socket.assigns.current_scope, socket.assigns.department, department_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"department" => department_params}, socket) do
    save_department(socket, socket.assigns.live_action, department_params)
  end

  defp save_department(socket, :edit, department_params) do
    case Organizations.update_department(socket.assigns.current_scope, socket.assigns.department, department_params) do
      {:ok, department} ->
        {:noreply,
         socket
         |> put_flash(:info, "Department updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, department)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_department(socket, :new, department_params) do
    case Organizations.create_department(socket.assigns.current_scope, department_params) do
      {:ok, department} ->
        {:noreply,
         socket
         |> put_flash(:info, "Department created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, department)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _department), do: ~p"/departments"
  defp return_path(_scope, "show", department), do: ~p"/departments/#{department}"
end
