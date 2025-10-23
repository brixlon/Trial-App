defmodule TrialAppWeb.PositionLive.Form do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations
  alias TrialApp.Organizations.Position

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage position records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="position-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="text" label="Description" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Position</.button>
          <.button navigate={return_path(@current_scope, @return_to, @position)}>Cancel</.button>
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
    position = Organizations.get_position!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Position")
    |> assign(:position, position)
    |> assign(:form, to_form(Organizations.change_position(socket.assigns.current_scope, position)))
  end

  defp apply_action(socket, :new, _params) do
    position = %Position{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Position")
    |> assign(:position, position)
    |> assign(:form, to_form(Organizations.change_position(socket.assigns.current_scope, position)))
  end

  @impl true
  def handle_event("validate", %{"position" => position_params}, socket) do
    changeset = Organizations.change_position(socket.assigns.current_scope, socket.assigns.position, position_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"position" => position_params}, socket) do
    save_position(socket, socket.assigns.live_action, position_params)
  end

  defp save_position(socket, :edit, position_params) do
    case Organizations.update_position(socket.assigns.current_scope, socket.assigns.position, position_params) do
      {:ok, position} ->
        {:noreply,
         socket
         |> put_flash(:info, "Position updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, position)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_position(socket, :new, position_params) do
    case Organizations.create_position(socket.assigns.current_scope, position_params) do
      {:ok, position} ->
        {:noreply,
         socket
         |> put_flash(:info, "Position created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, position)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _position), do: ~p"/positions"
  defp return_path(_scope, "show", position), do: ~p"/positions/#{position}"
end
