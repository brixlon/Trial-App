defmodule TrialAppWeb.UserLive.ForcePasswordChange do
  use TrialAppWeb, :live_view

  alias TrialApp.Accounts

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = Accounts.get_user!(user_id)

    form = to_form(%{
      "current_password" => "",
      "password" => "",
      "password_confirmation" => ""
    }, as: "user")

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:form, form)
     |> assign(:error_message, nil)
     |> assign(:trigger_submit, false)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    # Simple client-side validation feedback
    errors = []

    errors = if String.length(user_params["password"] || "") < 8 do
      ["Password must be at least 8 characters" | errors]
    else
      errors
    end

    errors = if user_params["password"] != user_params["password_confirmation"] do
      ["Passwords do not match" | errors]
    else
      errors
    end

    {:noreply, assign(socket, :error_message, Enum.join(errors, ", "))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    user = socket.assigns.user

    # Verify current password
    if Accounts.get_user_by_email_and_password(user.email, user_params["current_password"]) do
      # Update password and set must_change_password to false
      attrs = %{
        "password" => user_params["password"],
        "password_confirmation" => user_params["password_confirmation"]
      }

      case Accounts.update_user_password(user, attrs) do
        {:ok, {updated_user, _tokens}} ->
          # Update must_change_password flag
          Accounts.update_user(updated_user, %{must_change_password: false})

          {:noreply,
           socket
           |> put_flash(:info, "Password updated successfully! Logging you in...")
           |> assign(:trigger_submit, true)}

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")

          {:noreply, assign(socket, :error_message, errors)}
      end
    else
      {:noreply, assign(socket, :error_message, "Current password is incorrect")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-100 via-purple-50 to-pink-100 p-4">
      <div class="w-full max-w-md">
        <div class="bg-white rounded-2xl shadow-xl p-8">
          <div class="text-center mb-8">
            <div class="mx-auto w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mb-4">
              <svg class="w-8 h-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
            </div>
            <h2 class="text-3xl font-bold text-gray-900 mb-2">Change Your Password</h2>
            <p class="text-gray-600">
              For security reasons, you must change your password before continuing.
            </p>
          </div>

          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
            <div>
              <label for="current_password" class="block text-sm font-semibold text-gray-700 mb-2">
                Current Password
              </label>
              <input
                id="current_password"
                name="user[current_password]"
                type="password"
                required
                autocomplete="current-password"
                placeholder="Enter your temporary password"
                class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900"
              />
            </div>

            <div>
              <label for="password" class="block text-sm font-semibold text-gray-700 mb-2">
                New Password
              </label>
              <input
                id="password"
                name="user[password]"
                type="password"
                required
                autocomplete="new-password"
                placeholder="Choose a strong password"
                class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900"
              />
              <p class="text-xs text-gray-500 mt-1">Must be at least 8 characters</p>
            </div>

            <div>
              <label for="password_confirmation" class="block text-sm font-semibold text-gray-700 mb-2">
                Confirm New Password
              </label>
              <input
                id="password_confirmation"
                name="user[password_confirmation]"
                type="password"
                required
                autocomplete="new-password"
                placeholder="Re-enter your new password"
                class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900"
              />
            </div>

            <%= if @error_message do %>
              <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
                <%= @error_message %>
              </div>
            <% end %>

            <div class="bg-blue-50 border border-blue-200 text-blue-700 px-4 py-3 rounded-lg text-sm">
              <strong>Password Requirements:</strong>
              <ul class="list-disc list-inside mt-2 space-y-1">
                <li>At least 8 characters long</li>
                <li>Mix of letters and numbers recommended</li>
                <li>Avoid common passwords</li>
              </ul>
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition"
            >
              Update Password & Continue
            </button>
          </.form>
        </div>

        <p class="text-center text-sm text-gray-600 mt-6">
          Need help? Contact your administrator
        </p>
      </div>

      <%= if @trigger_submit do %>
        <form id="redirect-form" action={~p"/users/login?user_id=#{@user.id}"} method="get">
        </form>
        <script>
          document.getElementById('redirect-form').submit();
        </script>
      <% end %>
    </div>
    """
  end
end
