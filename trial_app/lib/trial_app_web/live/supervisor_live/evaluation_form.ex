
# lib/trial_app_web/live/supervisor_live/evaluation_form.ex

defmodule TrialAppWeb.SupervisorLive.EvaluationForm do
  use TrialAppWeb, :live_component

  alias TrialApp.Eams

  def mount(socket) do
    {:ok, assign(socket, submitting: false)}
  end

  def update(assigns, socket) do
    changeset =
      %Eams.Evaluation{}
      |> Eams.Evaluation.changeset(%{
        attachee_id: assigns.attachee.id,
        evaluator_id: assigns.current_user.id,
        score: 50
      }, assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  def handle_event("validate", %{"evaluation" => params}, socket) do
    changeset =
      %Eams.Evaluation{}
      |> Eams.Evaluation.changeset(params, socket.assigns.current_user)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"evaluation" => params}, socket) do
    socket = assign(socket, :submitting, true)

    case Eams.create_evaluation(params, socket.assigns.current_user) do
      {:ok, _eval} ->
        send(self(), {:evaluation_submitted, socket.assigns.attachee.id})
        send(self(), :close_modal)
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset, submitting: false)}
    end
  end

  def handle_event("close", _, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      phx-click="close"
      phx-target={@myself}
      phx-window-keydown="close"
      phx-key="Escape"
    >
      <div
        class="bg-white rounded-xl shadow-2xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto"
        phx-click-away="close"
        phx-target={@myself}
      >
        <div class="sticky top-0 bg-white border-b px-6 py-4 flex justify-between items-center">
          <div>
            <h2 class="text-2xl font-bold">Evaluate Attachee</h2>
            <p class="text-sm opacity-70">
              <%= @attachee.user.username || @attachee.user.email %>
            </p>
          </div>
          <button phx-click="close" phx-target={@myself} class="text-2xl">×</button>
        </div>

        <.form
          :let={f}
          for={@changeset}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="p-6 space-y-6"
        >
          <!-- SCORE -->
          <div>
            <label class="label">
              <span class="label-text font-bold">Score (1-100)</span>
            </label>
            <div class="flex items-center gap-4">
              <input
                type="range"
                name={f[:score].name}
                value={f[:score].value || 50}
                min="1"
                max="100"
                class="range range-primary"
                phx-debounce="100"
              />
              <span class="w-16 text-center font-bold text-xl">
                <%= f[:score].value || 50 %>
              </span>
            </div>
            <%= if msg = f[:score].errors[:score] do %>
              <p class="text-error text-sm mt-1"><%= msg %></p>
            <% end %>
          </div>

          <!-- COMMENTS -->
          <div>
            <label class="label">
              <span class="label-text font-bold">Comments <span class="text-red-500">*</span></span>
            </label>
            <textarea
              name={f[:comments].name}
              rows="6"
              class="textarea textarea-bordered w-full"
              placeholder="Write your feedback here..."
              required
              phx-debounce="500"
            ><%= f[:comments].value %></textarea>

            <%= if msg = f[:comments].errors[:comments] do %>
              <p class="text-error text-sm mt-1"><%= msg %></p>
            <% end %>
          </div>

          <!-- BUTTONS -->
          <div class="flex justify-end gap-3 pt-4 border-t">
            <button type="button" phx-click="close" phx-target={@myself} class="btn btn-ghost">
              Cancel
            </button>
            <button
              type="submit"
              class="btn btn-primary"
              disabled={!@changeset.valid? || @submitting}
            >
              <%= if @submitting, do: "Submitting...", else: "Submit Evaluation" %>
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
