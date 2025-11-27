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
     |> assign(:rating, nil)
     |> assign(:uploading?, false)}
  end

  def handle_event("rate_task", %{"rating" => rating, "comment" => comment}, socket) do
    task = socket.assigns.task
    current_user = socket.assigns.current_user

    case Eams.rate_attachee_task(
           task.id,
           %{rating: rating, rating_comment: comment},
           current_user
         ) do
      {:ok, updated_task} ->
        notify_attachee(updated_task, "rated", comment)
        send(self(), {:task_updated, updated_task})
        send(self(), :close_modal)
        {:noreply, socket}

      {:error, changeset} ->
        error_msg =
          changeset.errors
          |> Enum.map(fn {k, {msg, _}} -> "#{k} #{msg}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Failed to rate task: #{error_msg}")}
    end
  end

  def handle_event("update_comment", %{"comment" => comment}, socket) do
    {:noreply, assign(socket, :comment, comment)}
  end

  def handle_event("update_rating", %{"rating" => rating}, socket) do
    {:noreply, assign(socket, :rating, rating)}
  end

  defp notify_attachee(task, status, comment) do
    message = "Your task '#{task.title}' has been rated."

    PubSub.broadcast(
      TrialApp.PubSub,
      "attachee:#{task.assignee.user_id}",
      {:task_reviewed, %{task: task, status: status, comment: comment, message: message}}
    )
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
    >
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-screen overflow-y-auto">
        <div class="p-6">
          <!-- Header -->
          <div class="flex justify-between items-start mb-4">
            <div>
              <h2 class="text-2xl font-bold text-gray-800">{@task.title}</h2>
              <p class="text-sm text-gray-600">
                Submitted by
                <strong>{@task.assignee.user.username || @task.assignee.user.email}</strong>
                {Timex.from_now(@task.submitted_at)}
              </p>
            </div>
            <button
              phx-click={JS.push("close_modal") |> JS.hide(to: "##{@id}")}
              class="text-gray-400 hover:text-gray-600"
            >
              <.icon name="hero-x-mark" class="w-6 h-6" />
            </button>
          </div>
          
    <!-- File Preview -->
          <div class="mt-4 border rounded-lg overflow-hidden bg-gray-50">
            <%= if @task.submission_files && @task.submission_files != [] do %>
              <div class="p-4 space-y-2">
                <p class="text-sm font-medium text-gray-700">Attached Files:</p>
                <%= for file <- @task.submission_files do %>
                  <a
                    href={~p"/uploads/task_submissions/#{file}"}
                    target="_blank"
                    class="flex items-center gap-2 text-blue-600 hover:text-blue-800 p-2 bg-white rounded border hover:bg-blue-50 transition-colors"
                  >
                    <.icon name="hero-document" class="w-5 h-5" />
                    {file}
                  </a>
                <% end %>
              </div>
            <% else %>
              <div class="p-8 text-center text-gray-500">No file attached</div>
            <% end %>

            <%= if @task.submission_links && @task.submission_links != [] do %>
              <div class="p-4 border-t space-y-2">
                <p class="text-sm font-medium text-gray-700">Submission Links:</p>
                <%= for link <- @task.submission_links do %>
                  <a
                    href={link}
                    target="_blank"
                    class="flex items-center gap-2 text-blue-600 hover:text-blue-800"
                  >
                    <.icon name="hero-link" class="w-4 h-4" />
                    {link}
                  </a>
                <% end %>
              </div>
            <% end %>

            <%= if @task.submission_comment do %>
              <div class="p-4 border-t bg-gray-50">
                <p class="text-sm font-medium text-gray-700 mb-1">Attachee Comment:</p>
                <p class="text-gray-600 italic">"{@task.submission_comment}"</p>
              </div>
            <% end %>
          </div>
          
    <!-- Rating Section -->
          <div class="mt-6 bg-purple-50 p-6 rounded-xl border border-purple-100">
            <h3 class="text-lg font-semibold text-purple-900 mb-4">Task Evaluation</h3>

            <%= if @task.rating do %>
              <!-- Read-only view for rated tasks -->
              <div class="space-y-4">
                <div class="flex items-center gap-3">
                  <div class="text-sm font-medium text-gray-600">Rating:</div>
                  <div class={"px-3 py-1 rounded-full text-sm font-bold " <> rating_color(@task.rating)}>
                    {TrialApp.Eams.Task.rating_label(@task.rating)}
                  </div>
                </div>

                <div>
                  <div class="text-sm font-medium text-gray-600 mb-1">Supervisor Comment:</div>
                  <div class="bg-white p-4 rounded-lg border border-purple-100 text-gray-700">
                    {@task.rating_comment}
                  </div>
                </div>

                <div class="text-xs text-gray-500 mt-2">
                  Rated {Timex.format!(@task.rated_at, "%b %d, %Y at %H:%M", :strftime)}
                </div>
              </div>
            <% else %>
              <!-- Rating Form -->
              <form phx-submit="rate_task" phx-target={@myself} class="space-y-6">
                <div>
                  <label class="block text-sm font-medium text-purple-900 mb-2">Rating</label>
                  <div class="grid grid-cols-1 gap-3">
                    <%= for {label, value} <- TrialApp.Eams.Task.rating_options() do %>
                      <label class={"relative flex items-center p-4 cursor-pointer rounded-lg border transition-all " <> if(@rating == value, do: "border-purple-500 bg-purple-100 ring-1 ring-purple-500", else: "border-gray-200 bg-white hover:bg-gray-50")}>
                        <input
                          type="radio"
                          name="rating"
                          value={value}
                          class="h-4 w-4 text-purple-600 focus:ring-purple-500 border-gray-300"
                          phx-click="update_rating"
                          phx-value-rating={value}
                          phx-target={@myself}
                          checked={@rating == value}
                          required
                        />
                        <span class="ml-3 block text-sm font-medium text-gray-900">
                          {label}
                        </span>
                      </label>
                    <% end %>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-purple-900 mb-2">
                    Supervisor Comment <span class="text-red-500">*</span>
                    <span class="text-xs font-normal text-gray-500 ml-1">
                      (Required, min 10 chars)
                    </span>
                  </label>
                  <textarea
                    name="comment"
                    rows="4"
                    class="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                    placeholder="Provide feedback on the task performance..."
                    phx-change="update_comment"
                    phx-target={@myself}
                    required
                    minlength="10"
                  ><%= @comment %></textarea>
                </div>

                <div class="flex justify-end pt-4">
                  <button
                    type="submit"
                    class="px-6 py-2.5 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-lg hover:from-purple-700 hover:to-indigo-700 font-medium shadow-md transition-all transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                    disabled={is_nil(@rating) || String.length(@comment) < 10}
                  >
                    Submit Evaluation
                  </button>
                </div>
              </form>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp rating_color(rating) do
    case rating do
      "poor" -> "bg-red-100 text-red-800"
      "below_average" -> "bg-orange-100 text-orange-800"
      "average" -> "bg-yellow-100 text-yellow-800"
      "meets_expectations" -> "bg-blue-100 text-blue-800"
      "exceeds_expectations" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
