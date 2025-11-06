defmodule TrialAppWeb.AttacheeTaskSubmitLive do
  use TrialAppWeb, :live_view

  def mount(%{"id" => task_id}, _session, socket) do
    {:ok, assign(socket, task_id: task_id, page_title: "Submit Task")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold">Submit Task #<%= @task_id %></h1>
      <p class="mt-4">Task submission form will be implemented here.</p>
    </div>
    """
  end
end
