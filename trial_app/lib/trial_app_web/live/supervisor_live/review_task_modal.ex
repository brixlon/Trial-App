defmodule TrialAppWeb.SupervisorLive.ReviewTaskModal do
  use TrialAppWeb, :live_component

  alias TrialApp.Eams
  alias Phoenix.PubSub

  def update(%{task: task, current_user: user} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:task, task)
     |> assign(:current_user, user)
     |> assign(:comment, "")
     |> assign(:uploading?, false)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, push_event(socket, "close_modal", %{})}
  end

  def handle_event("reject", %{"comment" => comment}, socket) do
    task = socket.assigns.task

    case Eams.reject_attachee_task(task.id, comment) do
      {:ok, _} ->
        # TODO: Implement task comments feature if needed
        # Eams.create_task_comment(task.id, socket.assigns.current_user.id, comment)
        notify_attachee(task, "rejected", comment)
        send(self(), {:task_updated, task})
        {:noreply, push_event(socket, "close_modal", %{})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject task")}
    end
  end

  def handle_event("approve", %{"comment" => comment}, socket) do
    task = socket.assigns.task

    case Eams.approve_attachee_task(task.id) do
      {:ok, _} ->
        # TODO: Implement task comments feature if needed
        # Eams.create_task_comment(task.id, socket.assigns.current_user.id, comment)
        notify_attachee(task, "approved", comment)
        send(self(), {:task_updated, task})
        {:noreply, push_event(socket, "close_modal", %{})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve task")}
    end
  end

  def handle_event("update_comment", %{"comment" => comment}, socket) do
    {:noreply, assign(socket, :comment, comment)}
  end

  defp notify_attachee(task, status, comment) do
    message = case status do
      "approved" -> "Your task '#{task.title}' was approved!"
      "rejected" -> "Your task '#{task.title}' was rejected. See feedback."
    end

    PubSub.broadcast(
      TrialApp.PubSub,
      "attachee:#{task.assignee.user_id}",
      {:task_reviewed, %{task: task, status: status, comment: comment, message: message}}
    )
  end

  def render(assigns) do
    ~H"""
    <div id={@id} class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-screen overflow-y-auto">
        <div class="p-6">
          <!-- Header -->
          <div class="flex justify-between items-start mb-4">
            <div>
              <h2 class="text-2xl font-bold text-gray-800"><%= @task.title %></h2>
              <p class="text-sm text-gray-600">
                Submitted by <strong><%= @task.assignee.user.username || @task.assignee.user.email %></strong>
                <%= Timex.from_now(@task.submitted_at) %>
              </p>
            </div>
            <button phx-click="close_modal" phx-target={@myself} class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- File Preview -->
          <div class="mt-4 border rounded-lg overflow-hidden bg-gray-50">
            <%= if @task.submission do %>
              <iframe
                src={~p"/uploads/tasks/#{@task.submission}"}
                class="w-full h-96"
                frameborder="0"
              />
            <% else %>
              <div class="p-8 text-center text-gray-500">No file attached</div>
            <% end %>
          </div>

          <!-- Feedback -->
          <div class="mt-6">
            <label class="block text-sm font-medium text-gray-700 mb-2">Feedback (optional)</label>
            <textarea
              name="comment"
              rows="4"
              class="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              placeholder="Great work! Consider adding more data..."
              phx-change="update_comment"
              phx-target={@myself}
            ><%= @comment %></textarea>
          </div>

          <!-- Actions -->
          <div class="flex gap-3 justify-end mt-6">
            <button
              phx-click="reject"
              phx-value-comment={@comment}
              phx-target={@myself}
              class="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 font-medium"
            >
              Reject
            </button>
            <button
              phx-click="approve"
              phx-value-comment={@comment}
              phx-target={@myself}
              class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 font-medium"
            >
              Approve
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
