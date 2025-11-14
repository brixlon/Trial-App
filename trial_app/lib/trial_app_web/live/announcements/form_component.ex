defmodule TrialAppWeb.AnnouncementLive.FormComponent do
  use TrialAppWeb, :live_component

  alias TrialApp.Announcements

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:selected_targets, [])
     |> assign(:links, [])
     |> assign(:form_data, %{
       "title" => "",
       "content" => "",
       "category" => "",
       "priority" => "normal",
       "pinned" => "false"
     })}
  end

  @impl true
  def update(assigns, socket) do
    target_options = Announcements.get_target_options_for_role(assigns.active_role)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:target_options, target_options)}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("form_change", %{"title" => title, "content" => content, "category" => category, "priority" => priority} = params, socket) do
    form_data = %{
      "title" => title,
      "content" => content,
      "category" => category,
      "priority" => priority,
      "pinned" => Map.get(params, "pinned", "false")
    }
    {:noreply, assign(socket, :form_data, form_data)}
  end

  def handle_event("toggle_target", %{"target" => target}, socket) do
    selected_targets = socket.assigns.selected_targets

    new_selected_targets = if target in selected_targets do
      List.delete(selected_targets, target)
    else
      [target | selected_targets]
    end

    {:noreply, assign(socket, :selected_targets, new_selected_targets)}
  end

  def handle_event("add_link", %{"url" => url, "title" => title}, socket) do
    if url != "" do
      link = %{url: url, title: if(title == "", do: nil, else: title)}
      {:noreply, assign(socket, :links, socket.assigns.links ++ [link])}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_link", %{"index" => index}, socket) do
    index = String.to_integer(index)
    links = List.delete_at(socket.assigns.links, index)
    {:noreply, assign(socket, :links, links)}
  end

  def handle_event("create_announcement", params, socket) do
    form_data = socket.assigns.form_data

    title = Map.get(params, "title", form_data["title"])
    content = Map.get(params, "content", form_data["content"])
    category = Map.get(params, "category", form_data["category"])
    priority = Map.get(params, "priority", form_data["priority"])
    pinned = Map.get(params, "pinned", form_data["pinned"])

    # Parse targets to proper format
    targets = parse_selected_targets(socket.assigns.selected_targets)

    links = socket.assigns.links

    announcement_params = %{
      title: title,
      content: content,
      category: category,
      priority: priority,
      pinned: pinned == "true",
      publish_date: DateTime.utc_now(),
      creator_id: socket.assigns.current_user.id,
      creator_role: socket.assigns.active_role
    }

    case Announcements.create_announcement(announcement_params, targets, links) do
      {:ok, announcement} ->
        send(self(), {:announcement_created, announcement})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create announcement")}
    end
  end

  # Parse selected targets into proper database format
  defp parse_selected_targets(selected_targets) do
    Enum.flat_map(selected_targets, fn
      "everyone" ->
        [%{target_type: "everyone"}]

      "all_supervisors" ->
        [%{target_type: "all_supervisors"}]

      "all_attachees" ->
        [%{target_type: "all_attachees"}]

      "project_" <> project_id ->
        [%{target_type: "project", target_id: project_id}]

      "supervisor_" <> user_id ->
        [%{target_type: "specific_supervisor", target_id: user_id}]

      "attachee_" <> attachee_id ->
        [%{target_type: "specific_attachee", target_id: attachee_id}]

      other ->
        [%{target_type: other}]
    end)
  end

  def handle_event("close_modal", _, socket) do
    send(self(), {:close_modal, nil})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50" phx-click="close_modal">
      <div class="bg-white rounded-xl shadow-lg w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto" phx-click="stop_propagation" phx-target={@myself}>
        <div class="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between rounded-t-xl">
          <h2 class="text-xl font-bold text-gray-900">Create Announcement</h2>
          <button phx-click="close_modal" phx-target={@myself} class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <form phx-submit="create_announcement" phx-change="form_change" phx-target={@myself} class="p-6 space-y-5">
          <!-- Title -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Title *</label>
            <input
              type="text"
              name="title"
              value={@form_data["title"]}
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              placeholder="Enter announcement title"
            />
          </div>

          <!-- Content -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Content *</label>
            <textarea
              name="content"
              rows="6"
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 resize-none"
              placeholder="Write your announcement here..."
            ><%= @form_data["content"] %></textarea>
          </div>

          <!-- Category -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Category *</label>
            <select
              name="category"
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
            >
              <option value="">Choose a category</option>
              <option value="general_update" selected={@form_data["category"] == "general_update"}>General Update</option>
              <option value="training" selected={@form_data["category"] == "training"}>Training/Workshop</option>
              <option value="policy_change" selected={@form_data["category"] == "policy_change"}>Policy Change</option>
              <option value="event" selected={@form_data["category"] == "event"}>Event/Activity</option>
              <option value="deadline" selected={@form_data["category"] == "deadline"}>Deadline Reminder</option>
              <option value="recognition" selected={@form_data["category"] == "recognition"}>Recognition/Achievement</option>
              <option value="learning_materials" selected={@form_data["category"] == "learning_materials"}>Learning Materials</option>
            </select>
          </div>

          <!-- Priority -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Priority *</label>
            <select
              name="priority"
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
            >
              <option value="normal" selected={@form_data["priority"] == "normal"}>Normal</option>
              <option value="important" selected={@form_data["priority"] == "important"}>Important</option>
              <option value="urgent" selected={@form_data["priority"] == "urgent"}>Urgent</option>
            </select>
          </div>

          <!-- Pin to Top -->
          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              name="pinned"
              value="true"
              id="pinned"
              checked={@form_data["pinned"] == "true"}
              class="rounded border-gray-300 text-purple-600 focus:ring-purple-500"
            />
            <label for="pinned" class="text-sm font-medium text-gray-700">Pin to top</label>
          </div>

          <!-- Target Audience -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Target Audience *</label>

            <%= if @selected_targets == [] do %>
              <p class="text-sm text-amber-600 bg-amber-50 border border-amber-200 rounded-lg p-3 mb-3">
                ⚠️ Please select at least one target audience below
              </p>
            <% end %>

            <div class="space-y-3 max-h-64 overflow-y-auto border border-gray-200 rounded-lg p-4 bg-gray-50">
              <%= for option <- @target_options do %>
                <label class="flex items-start gap-3 p-3 bg-white rounded-lg border border-gray-200 hover:border-purple-300 hover:bg-purple-50 cursor-pointer transition">
                  <input
                    type="checkbox"
                    id={"target_#{option.value}"}
                    checked={option.value in @selected_targets}
                    phx-click="toggle_target"
                    phx-value-target={option.value}
                    phx-target={@myself}
                    class="mt-0.5 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                  />
                  <div class="flex-1">
                    <div class="text-sm font-medium text-gray-900"><%= option.label %></div>
                    <%= if option[:description] do %>
                      <div class="text-xs text-gray-500 mt-1"><%= option.description %></div>
                    <% end %>
                  </div>
                </label>
              <% end %>
            </div>

            <!-- Selected Targets Summary -->
            <%= if @selected_targets != [] do %>
              <div class="mt-3 p-3 bg-purple-50 border border-purple-200 rounded-lg">
                <p class="text-xs font-medium text-purple-900 mb-2">Selected Recipients:</p>
                <div class="flex flex-wrap gap-2">
                  <%= for target <- @selected_targets do %>
                    <span class="inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-800 rounded-full text-xs font-medium">
                      <%= get_target_label(target, @target_options) %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Links Section -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Learning Materials / Links (Optional)
            </label>

            <%= if @links != [] do %>
              <div class="space-y-2 mb-3">
                <%= for {link, index} <- Enum.with_index(@links) do %>
                  <div class="flex items-center gap-2 p-2 bg-gray-50 rounded border border-gray-200">
                    <svg class="w-4 h-4 text-purple-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                    </svg>
                    <div class="flex-1 min-w-0">
                      <%= if link.title do %>
                        <p class="text-sm font-medium text-gray-900 truncate"><%= link.title %></p>
                        <p class="text-xs text-gray-500 truncate"><%= link.url %></p>
                      <% else %>
                        <p class="text-sm text-gray-900 truncate"><%= link.url %></p>
                      <% end %>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_link"
                      phx-value-index={index}
                      phx-target={@myself}
                      class="text-red-500 hover:text-red-700 flex-shrink-0"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <input
                type="url"
                id="link-url"
                placeholder="https://example.com"
                class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              />
              <input
                type="text"
                id="link-title"
                placeholder="Link title (optional)"
                class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              />
            </div>
            <button
              type="button"
              phx-click="add_link"
              phx-value-url={Phoenix.HTML.Form.normalize_value("text", nil)}
              phx-value-title={Phoenix.HTML.Form.normalize_value("text", nil)}
              phx-target={@myself}
              onclick="
                const url = document.getElementById('link-url').value;
                const title = document.getElementById('link-title').value;
                this.setAttribute('phx-value-url', url);
                this.setAttribute('phx-value-title', title);
                document.getElementById('link-url').value = '';
                document.getElementById('link-title').value = '';
              "
              class="mt-2 w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 font-medium transition"
            >
              + Add Link
            </button>
          </div>

          <!-- Actions -->
          <div class="flex justify-end gap-3 pt-4 border-t">
            <button
              type="button"
              phx-click="close_modal"
              phx-target={@myself}
              class="px-5 py-2.5 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={@selected_targets == []}
              class={"px-5 py-2.5 rounded-lg font-medium transition shadow #{if @selected_targets == [], do: "bg-gray-300 text-gray-500 cursor-not-allowed", else: "bg-purple-600 text-white hover:bg-purple-700"}"}
            >
              Create Announcement
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  # Helper function to get target label
  defp get_target_label(target_value, target_options) do
    option = Enum.find(target_options, fn opt -> opt.value == target_value end)
    if option, do: option.label, else: target_value
  end
end
