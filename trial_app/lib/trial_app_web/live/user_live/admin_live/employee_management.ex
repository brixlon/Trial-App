defmodule TrialAppWeb.AdminLive.EmployeeManagement do
  use TrialAppWeb, :live_view
  alias TrialApp.{Orgs, Repo}

  @impl true
  def mount(_params, _session, socket) do
    departments = load_departments()

    {:ok,
     socket
     |> assign(:departments, departments)
     |> assign(:search, "")}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => q}}, socket) do
    {:noreply, assign(socket, :search, String.trim(q))}
  end

  defp load_departments do
    Orgs.list_departments()
    |> Repo.preload(employees: [:user, :team])
  end

  defp matches_search?(_employee, ""), do: true
  defp matches_search?(employee, query) do
    q = String.downcase(query)
    name = employee.name || ""
    email = employee.email || ""
    role = employee.role || ""
    team = (employee.team && employee.team.name) || ""

    Enum.any?([
      name,
      email,
      role,
      team
    ], fn val -> String.contains?(String.downcase(val), q) end)
  end

  @impl true
end
