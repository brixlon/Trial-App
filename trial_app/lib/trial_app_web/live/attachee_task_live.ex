defmodule TrialAppWeb.AttacheeTasksLive do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams, Repo}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    attachee = Eams.get_attachee_by_user(current_user.id)

    # Load tasks assigned to this attachee
    all_tasks = Eams.list_tasks_for_attachee(attachee.id) |> Repo.preload([:project])
    projects = Eams.list_projects_for_attachee(attachee.id)

    # Group tasks by status
    pending_tasks = Enum.filter(all_tasks, &(&1.status == "pending"))
    in_progress_tasks = Enum.filter(all_tasks, &(&1.status == "in_progress"))
    submitted_tasks = Enum.filter(all_tasks, &(&1.status == "submitted"))
    completed_tasks = Enum.filter(all_tasks, &(&1.status == "completed"))
    rejected_tasks = Enum.filter(all_tasks, &(&1.status == "rejected"))
    overdue_tasks = get_overdue_tasks(all_tasks)

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:attachee, attachee)
     |> assign(:all_tasks, all_tasks)
     |> assign(:projects, projects)
     |> assign(:pending_tasks, pending_tasks)
     |> assign(:in_progress_tasks, in_progress_tasks)
     |> assign(:submitted_tasks, submitted_tasks)
     |> assign(:completed_tasks, completed_tasks)
     |> assign(:rejected_tasks, rejected_tasks)
     |> assign(:overdue_tasks, overdue_tasks)
     |> assign(:selected_tab, "all")
     |> assign(:selected_task, nil)
     |> assign(:show_task_modal, false)
     |> assign(:show_submit_modal, false)
     |> assign(:submission_comment, "")
     |> assign(:submission_links, [])
     |> assign(:uploaded_files, [])
     |> assign(:page_title, "My Tasks")
     |> allow_upload(:task_files,
        accept: ~w(.pdf .doc .docx .txt .png .jpg .jpeg .zip .rar),
        max_entries: 5,
        max_file_size: 10_000_000)}  # 10MB
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  def handle_event("view_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id, %{preloads: [:project, assignee: :user]})

    {:noreply,
     socket
     |> assign(:selected_task, task)
     |> assign(:show_task_modal, true)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_task, nil)
     |> assign(:show_task_modal, false)
     |> assign(:show_submit_modal, false)
     |> assign(:submission_comment, "")
     |> assign(:submission_links, [])
     |> assign(:uploaded_files, [])}
  end

  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("start_task", %{"id" => id}, socket) do
    task = Eams.get_task!(id)

    case Eams.update_task(task, %{status: "in_progress"}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task started!")
         |> assign(:show_task_modal, false)
         |> reload_tasks()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start task")}
    end
  end

  def handle_event("open_submit_modal", %{"id" => id}, socket) do
    task = Eams.get_task!(id, %{preloads: [:project]})

    {:noreply,
     socket
     |> assign(:selected_task, task)
     |> assign(:show_task_modal, false)
     |> assign(:show_submit_modal, true)
     |> assign(:submission_comment, "")
     |> assign(:submission_links, [])
     |> assign(:uploaded_files, [])}
  end

  # Add link
  def handle_event("add_link", %{"link" => link}, socket) do
    if link != "" and valid_url?(link) do
      {:noreply, assign(socket, :submission_links, socket.assigns.submission_links ++ [link])}
    else
      {:noreply, put_flash(socket, :error, "Please enter a valid URL")}
    end
  end

  # Remove link
  def handle_event("remove_link", %{"index" => index}, socket) do
    index = String.to_integer(index)
    links = List.delete_at(socket.assigns.submission_links, index)
    {:noreply, assign(socket, :submission_links, links)}
  end

  # Cancel file upload
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :task_files, ref)}
  end

  # Validate uploaded files
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  # Submit task with comment, files, and links
  def handle_event("submit_task", %{"comment" => comment} = params, socket) do
    task = socket.assigns.selected_task
    current_links = socket.assigns.submission_links
    new_link = Map.get(params, "link", "") |> String.trim()

    final_links = if new_link != "" and valid_url?(new_link) do
      current_links ++ [new_link]
    else
      current_links
    end

    uploaded_files = upload_files(socket)

    submission_data = %{
      comment: comment,
      links: final_links,
      files: uploaded_files
    }

    case Eams.submit_attachee_task(task.id, submission_data) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_tasks()
         |> assign(:show_submit_modal, false)
         |> assign(:selected_task, nil)
         |> assign(:submission_links, [])
         |> assign(:uploaded_files, [])
         |> put_flash(:info, "Task submitted successfully! Supervisor can download files!")}

      {:error, reason} ->
        IO.inspect(reason, label: "SUBMISSION FAILED")
        {:noreply, put_flash(socket, :error, "Failed to submit. Try again.")}
    end
  end

  @impl true
  def handle_info({:switch_role, new_role}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.switch_user_role(user, new_role) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        redirect_path = case new_role do
          "admin" -> ~p"/admin/dashboard"
          "supervisor" -> ~p"/supervisor/dashboard"
          "attachee" -> ~p"/attachee"
          "manager" -> ~p"/dashboard"
          "employee" -> ~p"/dashboard"
          _ -> ~p"/dashboard"
        end

        {:noreply,
         socket
         |> assign(:current_scope, updated_scope)
         |> put_flash(:info, "Switched to #{new_role} role")
         |> push_navigate(to: redirect_path)}

      {:error, :unauthorized_role} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to switch to that role")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to switch role")}
    end
  end

  # Upload files helper
  defp upload_files(socket) do
    consume_uploaded_entries(socket, :task_files, fn %{path: temp_path}, entry ->
      upload_dir = Path.join([:code.priv_dir(:trial_app), "static", "uploads", "task_submissions"])
      File.mkdir_p!(upload_dir)

      ext = Path.extname(entry.client_name)
      filename = "#{DateTime.utc_now() |> DateTime.to_unix()}_#{entry.uuid}#{ext}"
      dest = Path.join(upload_dir, filename)

      File.cp!(temp_path, dest)

      {:ok, "/uploads/task_submissions/#{filename}"}
    end)
  end

  # URL validation
  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] && uri.host != nil
  end

  # Format file size
  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / (1024 * 1024), 1)} MB"

  # Upload error messages
  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(_), do: "Upload error"

  defp reload_tasks(socket) do
    attachee = socket.assigns.attachee
    all_tasks = Eams.list_tasks_for_attachee(attachee.id) |> Repo.preload([:project])

    pending_tasks = Enum.filter(all_tasks, &(&1.status == "pending"))
    in_progress_tasks = Enum.filter(all_tasks, &(&1.status == "in_progress"))
    submitted_tasks = Enum.filter(all_tasks, &(&1.status == "submitted"))
    completed_tasks = Enum.filter(all_tasks, &(&1.status == "completed"))
    rejected_tasks = Enum.filter(all_tasks, &(&1.status == "rejected"))
    overdue_tasks = get_overdue_tasks(all_tasks)

    socket
    |> assign(:all_tasks, all_tasks)
    |> assign(:pending_tasks, pending_tasks)
    |> assign(:in_progress_tasks, in_progress_tasks)
    |> assign(:submitted_tasks, submitted_tasks)
    |> assign(:completed_tasks, completed_tasks)
    |> assign(:rejected_tasks, rejected_tasks)
    |> assign(:overdue_tasks, overdue_tasks)
  end

  defp get_overdue_tasks(tasks) do
    today = Date.utc_today()

    Enum.filter(tasks, fn task ->
      task.due_on &&
      Date.compare(task.due_on, today) == :lt &&
      task.status not in ["completed", "submitted"]
    end)
  end

  defp is_overdue?(task) do
    task.due_on &&
    Date.compare(task.due_on, Date.utc_today()) == :lt &&
    task.status not in ["completed", "submitted"]
  end

  defp days_until_due(task) do
    if task.due_on do
      Date.diff(task.due_on, Date.utc_today())
    else
      nil
    end
  end

  defp days_overdue(task) do
    if task.due_on do
      Date.diff(Date.utc_today(), task.due_on)
    else
      0
    end
  end

  defp truncate(text, length) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end

  defp format_date(date) do
    if date do
      Calendar.strftime(date, "%b %d, %Y")
    else
      "Not set"
    end
  end

  defp due_date_class(due_date) do
    diff = Date.diff(due_date, Date.utc_today())
    cond do
      diff < 0 -> "text-red-600 text-xs font-medium"
      diff <= 2 -> "text-orange-600 text-xs font-medium"
      diff <= 7 -> "text-yellow-600 text-xs"
      true -> "text-gray-500 text-xs"
    end
  end

  defp relative_date(due_date) do
    diff = Date.diff(due_date, Date.utc_today())
    cond do
      diff < 0 -> "Overdue"
      diff == 0 -> "Today"
      diff == 1 -> "Tomorrow"
      diff <= 7 -> "In #{diff} days"
      true -> "In #{div(diff, 7)} weeks"
    end
  end

  defp get_tasks_for_tab(assigns) do
    case assigns.selected_tab do
      "pending" -> assigns.pending_tasks
      "in_progress" -> assigns.in_progress_tasks
      "submitted" -> assigns.submitted_tasks
      "completed" -> assigns.completed_tasks
      "all" -> assigns.all_tasks
      _ -> assigns.all_tasks
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <!-- Sidebar -->
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <!-- Main content -->
        <main class="ml-64 w-full p-8">
          <div class="max-w-7xl mx-auto space-y-8">
            <!-- Header -->
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-semibold text-gray-800">My Tasks</h1>
                <p class="text-gray-600 mt-1">View and manage your assigned tasks</p>
              </div>
              <.link navigate={~p"/attachee"} class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition font-medium">
                ← Back to Dashboard
              </.link>
            </div>

            <!-- Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-5 gap-6">
              <div class="bg-white shadow rounded-xl p-6">
                <p class="text-sm text-gray-600">Total Tasks</p>
                <p class="text-3xl font-bold text-purple-600 mt-2"><%= length(@all_tasks) %></p>
              </div>

              <div class="bg-gradient-to-br from-yellow-500 to-orange-500 text-white shadow rounded-xl p-6">
                <p class="text-sm opacity-90">Pending</p>
                <p class="text-3xl font-bold mt-2"><%= length(@pending_tasks) %></p>
              </div>

              <div class="bg-gradient-to-br from-blue-500 to-blue-700 text-white shadow rounded-xl p-6">
                <p class="text-sm opacity-90">In Progress</p>
                <p class="text-3xl font-bold mt-2"><%= length(@in_progress_tasks) %></p>
              </div>

              <div class="bg-gradient-to-br from-purple-500 to-purple-700 text-white shadow rounded-xl p-6">
                <p class="text-sm opacity-90">Submitted</p>
                <p class="text-3xl font-bold mt-2"><%= length(@submitted_tasks) %></p>
              </div>

              <div class="bg-gradient-to-br from-green-500 to-green-700 text-white shadow rounded-xl p-6">
                <p class="text-sm opacity-90">Completed</p>
                <p class="text-3xl font-bold mt-2"><%= length(@completed_tasks) %></p>
              </div>
            </div>

            <!-- Overdue Alert -->
            <%= if length(@overdue_tasks) > 0 do %>
              <div class="bg-red-50 border border-red-200 rounded-xl p-4 flex items-center gap-3">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                <div>
                  <span class="font-semibold text-red-800">Warning!</span>
                  <span class="text-red-700"> You have <%= length(@overdue_tasks) %> overdue task<%= if length(@overdue_tasks) > 1, do: "s" %></span>
                </div>
              </div>
            <% end %>

            <!-- Tabs -->
            <div class="bg-gray-100 p-2 rounded-xl inline-flex gap-2">
              <button
                phx-click="select_tab"
                phx-value-tab="all"
                class={"px-4 py-2 rounded-lg font-medium transition #{if @selected_tab == "all", do: "bg-white text-gray-900 shadow", else: "text-gray-600 hover:text-gray-900"}"}
              >
                All Tasks (<%= length(@all_tasks) %>)
              </button>
              <button
                phx-click="select_tab"
                phx-value-tab="pending"
                class={"px-4 py-2 rounded-lg font-medium transition #{if @selected_tab == "pending", do: "bg-white text-gray-900 shadow", else: "text-gray-600 hover:text-gray-900"}"}
              >
                Pending (<%= length(@pending_tasks) %>)
              </button>
              <button
                phx-click="select_tab"
                phx-value-tab="in_progress"
                class={"px-4 py-2 rounded-lg font-medium transition #{if @selected_tab == "in_progress", do: "bg-white text-gray-900 shadow", else: "text-gray-600 hover:text-gray-900"}"}
              >
                In Progress (<%= length(@in_progress_tasks) %>)
              </button>
              <button
                phx-click="select_tab"
                phx-value-tab="submitted"
                class={"px-4 py-2 rounded-lg font-medium transition #{if @selected_tab == "submitted", do: "bg-white text-gray-900 shadow", else: "text-gray-600 hover:text-gray-900"}"}
              >
                Submitted (<%= length(@submitted_tasks) %>)
              </button>
              <button
                phx-click="select_tab"
                phx-value-tab="completed"
                class={"px-4 py-2 rounded-lg font-medium transition #{if @selected_tab == "completed", do: "bg-white text-gray-900 shadow", else: "text-gray-600 hover:text-gray-900"}"}
              >
                Completed (<%= length(@completed_tasks) %>)
              </button>
            </div>

            <!-- Tasks Table -->
            <div class="bg-white shadow rounded-xl overflow-hidden">
              <div class="p-6">
                <%= if get_tasks_for_tab(assigns) == [] do %>
                  <div class="text-center py-12">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <p class="text-gray-500">No tasks found</p>
                  </div>
                <% else %>
                  <div class="overflow-x-auto">
                    <table class="min-w-full text-sm text-left text-gray-700">
                      <thead class="bg-gray-100 text-xs uppercase">
                        <tr>
                          <th class="px-4 py-3">Task</th>
                          <th class="px-4 py-3">Project</th>
                          <th class="px-4 py-3">Status</th>
                          <th class="px-4 py-3">Due Date</th>
                          <th class="px-4 py-3">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for task <- get_tasks_for_tab(assigns) do %>
                          <tr class={"border-t hover:bg-gray-50 transition #{if is_overdue?(task), do: "bg-red-50"}"}>
                            <td class="px-4 py-3">
                              <div class="font-medium text-gray-900"><%= task.title %></div>
                              <p class="text-sm text-gray-500 mt-1"><%= truncate(task.description, 80) %></p>
                              <%= if task.reject_reason do %>
                                <div class="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs">
                                  <span class="font-medium text-red-800">Feedback:</span>
                                  <span class="text-red-700"><%= task.reject_reason %></span>
                                </div>
                              <% end %>
                            </td>
                            <td class="px-4 py-3">
                              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                <%= task.project && task.project.name %>
                              </span>
                            </td>
                            <td class="px-4 py-3">
                              <span class={status_badge_class(task.status)}>
                                <%= format_status(task.status) %>
                              </span>
                            </td>
                            <td class="px-4 py-3">
                              <%= if task.due_on do %>
                                <div class="font-medium text-gray-900"><%= format_date(task.due_on) %></div>
                                <div class={due_date_class(task.due_on)}>
                                  <%= relative_date(task.due_on) %>
                                </div>
                              <% else %>
                                <span class="text-gray-400">—</span>
                              <% end %>
                            </td>
                            <td class="px-4 py-3">
                              <%= if task.status == "pending" do %>
                                <button
                                  phx-click="start_task"
                                  phx-value-id={task.id}
                                  class="bg-purple-600 text-white px-4 py-2 rounded-lg shadow hover:bg-purple-700 text-sm font-medium"
                                >
                                  Start Task
                                </button>
                              <% end %>
                              <%= if task.status in ["in_progress", "rejected"] do %>
                                <button
                                  phx-click="open_submit_modal"
                                  phx-value-id={task.id}
                                  class="bg-purple-600 text-white px-4 py-2 rounded-lg shadow hover:bg-purple-700 text-sm font-medium"
                                >
                                  Submit
                                </button>
                              <% end %>
                              <%= if task.status == "submitted" do %>
                                <span class="text-sm text-gray-500">Under Review</span>
                              <% end %>
                              <%= if task.status == "completed" do %>
                                <span class="text-sm text-green-600 font-medium">Completed</span>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </main>
      </div>

      <!-- SUBMIT TASK MODAL -->
      <%= if @show_submit_modal && @selected_task do %>
        <div
          id="submit-task-modal"
          class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
          phx-click="close_modal"
        >
          <div
            class="bg-white rounded-xl shadow-lg w-full max-w-lg mx-4 p-6"
            phx-click="stop_propagation"
          >
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-bold text-gray-900">
                Submit Task: <%= @selected_task.title %>
              </h2>
              <button
                phx-click="close_modal"
                class="text-gray-400 hover:text-gray-600"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <p class="text-sm text-gray-600 mb-5">
              Add your comments, relevant links, and attach files related to your work.
            </p>

            <form phx-submit="submit_task" phx-change="validate_upload" class="space-y-5">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Comments *</label>
                <textarea
                  name="comment"
                  rows="4"
                  class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 resize-none"
                  placeholder="Describe what you did, challenges faced, or any questions..."
                  required
                ><%= @submission_comment %></textarea>
              </div>

              <!-- Links Section -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Links (Optional)
                  <span class="text-xs text-gray-500 ml-1">- GitHub, Google Drive, etc.</span>
                </label>

                <%= if @submission_links != [] do %>
                  <div class="space-y-2 mb-3">
                    <%= for {link, index} <- Enum.with_index(@submission_links) do %>
                      <div class="flex items-center gap-2 p-2 bg-gray-50 rounded border border-gray-200">
                        <svg class="w-4 h-4 text-blue-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                        </svg>
                        <a href={link} target="_blank" class="text-sm text-blue-600 hover:underline flex-1 truncate"><%= link %></a>
                        <button
                          type="button"
                          phx-click="remove_link"
                          phx-value-index={index}
                          class="text-red-500 hover:text-red-700 flex-shrink-0"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <div class="flex gap-2">
                  <input
                    type="url"
                    name="link"
                    id="link-input"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 text-sm"
                    placeholder="https://github.com/username/repo or https://drive.google.com/..."
                  />
                  <button
                    type="button"
                    phx-click="add_link"
                    phx-value-link={Phoenix.HTML.Form.normalize_value("text", Phoenix.HTML.Form.input_value(:link, "link-input"))}
                    onclick="document.getElementById('link-input').value = ''"
                    class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 text-sm font-medium"
                  >
                    Add Link
                  </button>
                </div>
              </div>

              <!-- File Upload Section -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Attach Files (Optional)
                  <span class="text-xs text-gray-500 ml-1">- Max 5 files, 10MB each</span>
                </label>

                <div class="mt-1">
                  <label class="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
                    <div class="flex flex-col items-center justify-center pt-5 pb-6">
                      <svg class="w-8 h-8 mb-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                      </svg>
                      <p class="mb-1 text-sm text-gray-500"><span class="font-semibold">Click to upload</span> or drag and drop</p>
                      <p class="text-xs text-gray-500">PDF, DOC, DOCX, TXT, PNG, JPG, ZIP</p>
                    </div>
                    <.live_file_input upload={@uploads.task_files} class="hidden" />
                  </label>
                </div>

                <!-- Display uploaded files -->
                <%= for entry <- @uploads.task_files.entries do %>
                  <div class="mt-2 flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-200">
                    <div class="flex items-center gap-2 flex-1">
                      <svg class="w-5 h-5 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                        <p class="text-xs text-gray-500"><%= format_file_size(entry.client_size) %></p>
                      </div>
                      <!-- Progress bar -->
                      <div class="w-24">
                        <div class="w-full bg-gray-200 rounded-full h-1.5">
                          <div class="bg-purple-600 h-1.5 rounded-full" style={"width: #{entry.progress}%"}></div>
                        </div>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="ml-3 text-red-500 hover:text-red-700"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>

                  <%= for err <- upload_errors(@uploads.task_files, entry) do %>
                    <p class="mt-1 text-sm text-red-600"><%= error_to_string(err) %></p>
                  <% end %>
                <% end %>
              </div>

              <div class="flex justify-end gap-3 pt-3 border-t">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-5 py-2.5 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-5 py-2.5 bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium transition shadow"
                >
                  Submit Task
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "px-2.5 py-0.5 bg-yellow-100 text-yellow-800 rounded-full text-xs font-medium"
  defp status_badge_class("in_progress"), do: "px-2.5 py-0.5 bg-blue-100 text-blue-800 rounded-full text-xs font-medium"
  defp status_badge_class("submitted"), do: "px-2.5 py-0.5 bg-purple-100 text-purple-800 rounded-full text-xs font-medium"
  defp status_badge_class("completed"), do: "px-2.5 py-0.5 bg-green-100 text-green-800 rounded-full text-xs font-medium"
  defp status_badge_class("rejected"), do: "px-2.5 py-0.5 bg-red-100 text-red-800 rounded-full text-xs font-medium"
  defp status_badge_class(_), do: "px-2.5 py-0.5 bg-gray-100 text-gray-800 rounded-full text-xs font-medium"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
