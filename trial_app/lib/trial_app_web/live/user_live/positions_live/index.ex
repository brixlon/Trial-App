defmodule TrialAppWeb.PositionLive.Index do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Mock data
    positions = [
      %{id: 1, title: "Senior Developer", description: "Lead development", salary_range: "$100k - $150k"},
      %{id: 2, title: "HR Manager", description: "Manage HR", salary_range: "$80k - $120k"}
    ]
    {:ok, stream(socket, :positions, positions)}
  end
end
