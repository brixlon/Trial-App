defmodule TrialAppWeb.EmployeeLive.Form do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations
  alias TrialApp.Organizations.Employee

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage employee records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="employee-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:email]} type="text" label="Email" />
        <.input field={@form[:position]} type="text" label="Position" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Employee</.button>
          <.button navigate={return_path(@current_scope, @return_to, @employee)}>Cancel</.button>
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
    employee = Organizations.get_employee!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Employee")
    |> assign(:employee, employee)
    |> assign(:form, to_form(Organizations.change_employee(socket.assigns.current_scope, employee)))
  end

  defp apply_action(socket, :new, _params) do
    employee = %Employee{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Employee")
    |> assign(:employee, employee)
    |> assign(:form, to_form(Organizations.change_employee(socket.assigns.current_scope, employee)))
  end

  @impl true
  def handle_event("validate", %{"employee" => employee_params}, socket) do
    changeset = Organizations.change_employee(socket.assigns.current_scope, socket.assigns.employee, employee_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"employee" => employee_params}, socket) do
    save_employee(socket, socket.assigns.live_action, employee_params)
  end

  defp save_employee(socket, :edit, employee_params) do
    case Organizations.update_employee(socket.assigns.current_scope, socket.assigns.employee, employee_params) do
      {:ok, employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, employee)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_employee(socket, :new, employee_params) do
    case Organizations.create_employee(socket.assigns.current_scope, employee_params) do
      {:ok, employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, employee)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _employee), do: ~p"/employees"
  defp return_path(_scope, "show", employee), do: ~p"/employees/#{employee}"
end
