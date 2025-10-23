defmodule TrialAppWeb.TeamLive.Form do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations
  alias TrialApp.Organizations.Team

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage team records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="team-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Team</.button>
          <.button navigate={return_path(@current_scope, @return_to, @team)}>Cancel</.button>
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
    team = Organizations.get_team!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Team")
    |> assign(:team, team)
    |> assign(:form, to_form(Organizations.change_team(socket.assigns.current_scope, team)))
  end

  defp apply_action(socket, :new, _params) do
    team = %Team{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Team")
    |> assign(:team, team)
    |> assign(:form, to_form(Organizations.change_team(socket.assigns.current_scope, team)))
  end

  @impl true
  def handle_event("validate", %{"team" => team_params}, socket) do
    changeset = Organizations.change_team(socket.assigns.current_scope, socket.assigns.team, team_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"team" => team_params}, socket) do
    save_team(socket, socket.assigns.live_action, team_params)
  end

  defp save_team(socket, :edit, team_params) do
    case Organizations.update_team(socket.assigns.current_scope, socket.assigns.team, team_params) do
      {:ok, team} ->
        {:noreply,
         socket
         |> put_flash(:info, "Team updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, team)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_team(socket, :new, team_params) do
    case Organizations.create_team(socket.assigns.current_scope, team_params) do
      {:ok, team} ->
        {:noreply,
         socket
         |> put_flash(:info, "Team created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, team)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _team), do: ~p"/teams"
  defp return_path(_scope, "show", team), do: ~p"/teams/#{team}"
end
