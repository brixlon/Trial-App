defmodule TrialAppWeb.TeamLive.Show do
  use TrialAppWeb, :live_view

  alias TrialApp.Organizations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Team {@team.id}
        <:subtitle>This is a team record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/teams"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/teams/#{@team}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit team
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@team.name}</:item>
        <:item title="Description">{@team.description}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Organizations.subscribe_teams(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Team")
     |> assign(:team, Organizations.get_team!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %TrialApp.Organizations.Team{id: id} = team},
        %{assigns: %{team: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :team, team)}
  end

  def handle_info(
        {:deleted, %TrialApp.Organizations.Team{id: id}},
        %{assigns: %{team: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current team was deleted.")
     |> push_navigate(to: ~p"/teams")}
  end

  def handle_info({type, %TrialApp.Organizations.Team{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
