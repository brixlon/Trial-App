defmodule TrialAppWeb.AttacheeProfileLive do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Eams, Repo}
  import TrialAppWeb.Live.Helpers.RoleSwitcher

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    attachee = Eams.get_attachee_by_user(user.id) |> Repo.preload([:organization, :department, :user])

    all_tasks = Eams.list_tasks_for_attachee(attachee.id)
    total = length(all_tasks)
    completed = Enum.count(all_tasks, &(&1.status == "completed"))
    overdue = Enum.count(all_tasks, &is_overdue?/1)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:attachee, attachee)
     |> assign(:total_tasks, total)
     |> assign(:completed_tasks, completed)
     |> assign(:overdue_tasks, overdue)}
  end

  @impl true
  def handle_info({:switch_role, new_role}, socket), do: handle_role_switch(socket, new_role)

  # -----------------------------------------------------------------
  # Helpers
  # -----------------------------------------------------------------
  defp is_overdue?(task) do
    task.due_on && Date.compare(task.due_on, Date.utc_today()) == :lt &&
      task.status not in ["completed", "submitted"]
  end

  defp format_date(date), do: if(date, do: Calendar.strftime(date, "%b %d, %Y"), else: "—")

  defp supervisor_name(attachee) do
    case Eams.list_tasks_for_attachee(attachee.id) |> Repo.preload(project: :supervisor) do
      [] -> "—"
      [%{project: %{supervisor: sup}} | _] -> sup.username || sup.email
      _ -> "—"
    end
  end

  defp get_initials(username) do
    case username do
      nil -> "A"
      name ->
        name
        |> String.split()
        |> Enum.map(&String.first/1)
        |> Enum.join()
        |> String.slice(0, 2)
        |> String.upcase()
    end
  end

  # -----------------------------------------------------------------
  # Render
  # -----------------------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">

        <main class="flex-1 ml-64 p-8">
          <div class="max-w-4xl mx-auto space-y-8">

            <!-- Header -->
            <div class="flex justify-between items-center">
              <div>
                <h1 class="text-3xl font-bold text-gray-800">My Profile</h1>
                <p class="text-gray-600">View and manage your attachee information</p>
              </div>
              <.link navigate={~p"/attachee/tasks"} class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 text-sm font-medium">
                View Tasks
              </.link>
            </div>

            <!-- Profile Card -->
            <div class="bg-white shadow rounded-xl p-6">
              <div class="flex items-start gap-6">
                <!-- NAME INITIALS AVATAR -->
                <div class="shrink-0">
                  <div class="w-24 h-24 rounded-full shadow-lg bg-gradient-to-br from-purple-600 to-indigo-700 flex items-center justify-center">
                    <span class="text-white text-2xl font-bold">
                      <%= get_initials(@attachee.user.username) %>
                    </span>
                  </div>
                </div>

                <div class="flex-1">
                  <div class="flex items-center gap-3">
                    <h2 class="text-2xl font-bold text-gray-900">
                      <%= @attachee.user.username || "Attachee" %>
                    </h2>
                    <span class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-xs font-medium">
                      Attachee
                    </span>
                  </div>
                  <p class="text-gray-600"><%= @attachee.user.email %></p>
                </div>
              </div>
            </div>

            <!-- Rest of the profile -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="bg-white shadow rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-800 mb-4">Personal Information</h3>
                <dl class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Phone</dt>
                    <dd class="font-medium"><%= @attachee.user.phone_number || "—" %></dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Position</dt>
                    <dd class="font-medium"><%= @attachee.position %></dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Attachment Period</dt>
                    <dd class="font-medium">
                      <%= format_date(@attachee.starts_on) %> to <%= format_date(@attachee.ends_on) %>
                    </dd>
                  </div>
                </dl>
              </div>

              <div class="bg-white shadow rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-800 mb-4">Organization</h3>
                <dl class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Company</dt>
                    <dd class="font-medium"><%= @attachee.organization.name %></dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Department</dt>
                    <dd class="font-medium"><%= @attachee.department.name %></dd>
                  </div>
                  <div class="flex justify-between">
                    <dt class="text-gray-500">Supervisor</dt>
                    <dd class="font-medium"><%= supervisor_name(@attachee) %></dd>
                  </div>
                </dl>
              </div>
            </div>

            <!-- Task Summary -->
            <div class="bg-white shadow rounded-xl p-6">
              <h3 class="text-lg font-semibold text-gray-800 mb-4">Task Summary</h3>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6 text-center">
                <div>
                  <p class="text-3xl font-bold text-purple-600"><%= @total_tasks %></p>
                  <p class="text-sm text-gray-600">Total Tasks</p>
                </div>
                <div>
                  <p class="text-3xl font-bold text-green-600"><%= @completed_tasks %></p>
                  <p class="text-sm text-gray-600">Completed</p>
                </div>
                <div>
                  <p class={"text-3xl font-bold #{if @overdue_tasks > 0, do: "text-red-600", else: "text-gray-600"}"}>
                    <%= @overdue_tasks %>
                  </p>
                  <p class="text-sm text-gray-600">Overdue</p>
                </div>
              </div>
            </div>

            <!-- Actions -->
            <div class="flex gap-3">
              <button class="px-5 py-2.5 bg-purple-600 text-white rounded-lg hover:bg-purple-700 shadow">
                Edit Profile
              </button>
              <button class="px-5 py-2.5 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50">
                Download Report
              </button>
            </div>

          </div>
        </main>
      </div>
    </div>
    """
  end
end
