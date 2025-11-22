defmodule TrialAppWeb.AdminLive.ReviewTasksLive do
  use TrialAppWeb, :live_view

  alias TrialApp.Eams
  alias TrialApp.Repo

  # --------------------------------------------------------------------
  # Mount
  # --------------------------------------------------------------------
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_reject_modal, false)
     |> assign(:reject_task, nil)
     |> load_submitted_tasks()}
  end

  # --------------------------------------------------------------------
  # Event Handlers
  # --------------------------------------------------------------------
  def handle_event("approve", %{"task_id" => task_id}, socket) do
    task = Eams.get_task!(task_id)

    {:ok, _} =
      Eams.update_task(task, %{status: "completed", reject_reason: nil})

    {:noreply,
     socket
     |> load_submitted_tasks()
     |> put_flash(:info, "Task approved!")}
  end

  def handle_event("send_back", %{"task_id" => task_id}, socket) do
    task = Eams.get_task!(task_id)

    {:noreply,
     socket
     |> assign(:show_reject_modal, true)
     |> assign(:reject_task, task)}
  end

  def handle_event("close_reject_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_reject_modal, false)
     |> assign(:reject_task, nil)}
  end

  def handle_event(
        "reject_with_reason",
        %{"task_id" => task_id, "reason" => reason},
        socket
      ) do
    task = Eams.get_task!(task_id)

    {:ok, _} =
      Eams.update_task(task, %{
        status: "in_progress",
        reject_reason: reason
      })

    {:noreply,
     socket
     |> assign(:show_reject_modal, false)
     |> assign(:reject_task, nil)
     |> load_submitted_tasks()
     |> put_flash(:info, "Task sent back with feedback.")}
  end

  # --------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------
  defp load_submitted_tasks(socket) do
    tasks =
      Eams.list_tasks()
      |> Repo.preload([:project, assignee: [:user]])
      |> Enum.filter(&(&1.status == "submitted"))
      |> Enum.sort_by(&{&1.assignee_id || 0, &1.inserted_at}, {:asc, :desc})

    grouped =
      tasks
      |> Enum.group_by(& &1.assignee)
      |> Enum.reject(&(elem(&1, 0) == nil))
      |> Enum.sort_by(fn {attachee, _} -> get_attachee_name(attachee) end)

    assign(socket, :grouped_tasks, grouped)
  end

  defp get_attachee_name(attachee) do
    cond do
      Map.get(attachee, :first_name) && Map.get(attachee, :last_name) ->
        "#{attachee.first_name} #{attachee.last_name}"

      attachee.user && attachee.user.username ->
        attachee.user.username

      attachee.user && attachee.user.email ->
        attachee.user.email

      true ->
        "Attachee ##{attachee.id}"
    end
  end

  defp get_initials(attachee) do
    cond do
      Map.get(attachee, :first_name) && Map.get(attachee, :last_name) ->
        "#{String.first(attachee.first_name)}#{String.first(attachee.last_name)}"

      attachee.user && attachee.user.username ->
        String.slice(attachee.user.username, 0..1) |> String.upcase()

      true ->
        "A"
    end
  end

  defp format_date(date),
    do: Calendar.strftime(date, "%B %d, %Y at %I:%M%p")

  # --------------------------------------------------------------------
  # Render
  # --------------------------------------------------------------------
  def render(assigns) do
    ~H"""
    <div class="ml-45 p-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">Review Submitted Tasks</h1>
      <p class="text-gray-600 mb-6">Approve or send back tasks with feedback</p>

      <%= if Enum.empty?(@grouped_tasks) do %>
        <div class="bg-white rounded-xl border p-12 text-center">
          <p class="text-gray-500">No tasks awaiting review.</p>
        </div>
      <% else %>
        <div class="space-y-6">
          <%= for {attachee, tasks} <- @grouped_tasks do %>
            <div class="bg-white rounded-xl border p-6">
              <div class="flex items-center mb-4">
                <div class="h-12 w-12 rounded-full bg-indigo-600 text-white flex items-center justify-center font-bold text-lg">
                  {get_initials(attachee)}
                </div>
                <div class="ml-4">
                  <h3 class="font-semibold text-lg">{get_attachee_name(attachee)}</h3>
                  <p class="text-sm text-gray-500">{attachee.user.email}</p>
                </div>
                <div class="ml-auto">
                  <span class="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-full text-xs font-medium">
                    {length(tasks)} submitted
                  </span>
                </div>
              </div>

              <div class="space-y-3">
                <%= for task <- tasks do %>
                  <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                    <div class="flex-1">
                      <p class="font-medium">{task.title}</p>
                      <p class="text-sm text-gray-600">{task.project.name}</p>
                      <p class="text-xs text-gray-500">
                        Submitted {format_date(task.updated_at)}
                      </p>
                    </div>

                    <div class="flex gap-2">
                      <button
                        phx-click="send_back"
                        phx-value-task_id={task.id}
                        class="px-4 py-2 text-sm font-medium text-red-700 bg-red-100 rounded-lg hover:bg-red-200"
                      >
                        Send Back
                      </button>

                      <button
                        phx-click="approve"
                        phx-value-task_id={task.id}
                        class="px-4 py-2 text-sm font-medium text-green-700 bg-green-100 rounded-lg hover:bg-green-200"
                      >
                        Approve
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
      
    <!-- Reject Reason Modal -->
      <%= if @show_reject_modal && @reject_task do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl max-w-md w-full p-6">
            <h3 class="text-lg font-semibold mb-4">Send Task Back</h3>

            <p class="text-sm text-gray-600 mb-4">
              Why are you sending "<strong><%= @reject_task.title %></strong>" back?
            </p>

            <form phx-submit="reject_with_reason">
              <input type="hidden" name="task_id" value={@reject_task.id} />

              <textarea
                name="reason"
                class="w-full border rounded-lg p-3 text-sm"
                rows="4"
                placeholder="E.g., More details needed in the report..."
                required
              ></textarea>

              <div class="flex justify-end gap-3 mt-6">
                <button
                  type="button"
                  phx-click="close_reject_modal"
                  class="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  Send Back
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
