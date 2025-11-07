# lib/trial_app_web/live/supervisor_live/evaluation_form.ex

defmodule TrialAppWeb.SupervisorLive.EvaluationForm do
  use TrialAppWeb, :live_component
  import TrialAppWeb.CoreComponents, except: [translate_error: 1]  # 👈 Prevent conflict

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
        score: 50,
        comments: ""
      }, assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  def handle_event("validate", %{"evaluation" => params}, socket) do
    params =
      Map.merge(params, %{
        "attachee_id" => socket.assigns.attachee.id,
        "evaluator_id" => socket.assigns.current_user.id
      })

    changeset =
      %Eams.Evaluation{}
      |> Eams.Evaluation.changeset(params, socket.assigns.current_user)
      |> Map.put(:action, :validate)

    IO.inspect(changeset.valid?, label: "Changeset Valid?")
    IO.inspect(changeset.errors, label: "Changeset Errors")
    IO.inspect(params, label: "Params")

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"evaluation" => params}, socket) do
    IO.puts("\n=== SAVE EVENT TRIGGERED ===")
    IO.inspect(params, label: "Raw params")

    socket = assign(socket, :submitting, true)

    params =
      Map.merge(params, %{
        "attachee_id" => socket.assigns.attachee.id,
        "evaluator_id" => socket.assigns.current_user.id
      })

    IO.inspect(params, label: "Merged params")

    case Eams.create_evaluation(params, socket.assigns.current_user) do
      {:ok, eval} ->
        IO.puts("✅ Evaluation created successfully!")
        IO.inspect(eval, label: "Created evaluation")
        send(self(), {:evaluation_submitted, socket.assigns.attachee.id})
        send(self(), :close_modal)
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.puts("❌ Evaluation creation failed!")
        IO.inspect(changeset.errors, label: "Save errors")
        {:noreply, assign(socket, changeset: changeset, submitting: false)}
    end
  end

  def handle_event("close", _, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end

  # Custom helper to translate local error tuples safely
  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      phx-window-keydown="close"
      phx-key="Escape"
      phx-target={@myself}
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
                name="evaluation[score]"
                value={Phoenix.HTML.Form.input_value(f, :score) || 50}
                min="1"
                max="100"
                class="range range-primary"
                phx-debounce="100"
              />
              <span class="w-16 text-center font-bold text-xl">
                <%= Phoenix.HTML.Form.input_value(f, :score) || 50 %>
              </span>
            </div>
          </div>

          <!-- COMMENTS -->
          <div>
            <label class="label">
              <span class="label-text font-bold">Comments <span class="text-red-500">*</span></span>
              <span class="label-text-alt text-base-content/50">Minimum 10 characters</span>
            </label>
            <textarea
              name="evaluation[comments]"
              rows="6"
              class={"textarea textarea-bordered w-full #{if @changeset.errors[:comments], do: "textarea-error"}"}
              placeholder="Write your feedback here... (minimum 10 characters)"
              phx-debounce="500"
            ><%= Phoenix.HTML.Form.input_value(f, :comments) %></textarea>
            <%= if error = Keyword.get(@changeset.errors, :comments) do %>
              <p class="text-error text-sm mt-1">
                <%= translate_error(error) %>
              </p>
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
              disabled={@submitting}
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
