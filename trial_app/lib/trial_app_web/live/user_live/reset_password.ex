defmodule TrialAppWeb.UserLive.ResetPassword do
  use TrialAppWeb, :live_view

  alias TrialApp.Accounts
  alias TrialApp.Accounts.UserNotifier

  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    Logger.info("=== Reset Password Mount ===")
    Logger.info("Token received: #{String.slice(token, 0, 10)}...")

    case Accounts.verify_force_reset_token(token) do
      %Accounts.User{} = user ->
        Logger.info("Token verified for user ID: #{user.id}")

        form =
          Phoenix.Component.to_form(
            %{"password" => "", "password_confirmation" => ""},
            as: "user"
          )

        {:ok,
         assign(socket,
           form: form,
           user: user,
           token: token,
           error_message: nil,
           show_password: false,
           submitting: false
         )}

      nil ->
        Logger.warning("Invalid or expired token")

        {:ok,
         socket
         |> put_flash(:error, "Invalid or expired reset token. Please request a new one.")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("show_password", _params, socket) do
    {:noreply, assign(socket, show_password: !socket.assigns.show_password)}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    %{user: user} = socket.assigns

    Logger.info("=== Password Reset Event ===")
    Logger.info("User ID: #{inspect(user && user.id)}")

    if is_nil(user) do
      Logger.warning("User is nil - redirecting")
      {:noreply,
       socket
       |> put_flash(:error, "Invalid or expired reset token")
       |> push_navigate(to: ~p"/")}
    else
      # Use handle_info to process the reset asynchronously
      # This prevents the LiveView from timing out
      send(self(), {:do_reset, user_params})
      {:noreply, assign(socket, submitting: true, error_message: nil)}
    end
  rescue
    e ->
      Logger.error("Error in reset_password event: #{Exception.message(e)}")
      {:noreply, assign(socket, error_message: "An error occurred. Please try again.", submitting: false)}
  end

  @impl true
  def handle_info({:do_reset, user_params}, socket) do
    %{user: user} = socket.assigns

    Logger.info("Processing password reset...")

    case Accounts.reset_user_password(user, user_params) do
      {:ok, {updated_user, _tokens}} ->
        Logger.info("Password reset successful!")

        # Send confirmation email in background
        Task.start(fn ->
          try do
            UserNotifier.deliver_password_reset_confirmation(updated_user)
            Logger.info("Confirmation email queued")
          rescue
            e -> Logger.error("Email error: #{inspect(e)}")
          end
        end)

        {:noreply,
         socket
         |> assign(submitting: false)
         |> put_flash(:info, "Password reset successfully. Please log in with your new password.")
         |> push_navigate(to: ~p"/")}

      {:error, changeset} ->
        Logger.error("Password reset failed: #{inspect(changeset.errors)}")

        error_msg =
          changeset.errors
          |> Enum.map(fn
            {field, {msg, _}} -> "#{field}: #{msg}"
            {field, msg} -> "#{field}: #{msg}"
          end)
          |> Enum.join(", ")
          |> case do
            "" -> "Unable to reset password. Please try again."
            msg -> msg
          end

        {:noreply, assign(socket, error_message: error_msg, submitting: false)}
    end
  rescue
    e ->
      Logger.error("Error in do_reset: #{Exception.message(e)}")
      Logger.error(Exception.format_stacktrace(__STACKTRACE__))
      {:noreply, assign(socket, error_message: "An error occurred. Please try again.", submitting: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <div class="w-full max-w-md">
        <div class="text-center mb-8">
          <img src={~p"/images/value8-logo.png"} alt="Value8 Logo" class="h-10 mx-auto mb-6" />
          <h3 class="text-3xl font-semibold text-gray-800 mb-2">Reset Password</h3>
          <p class="text-gray-600">Enter your new password below</p>
        </div>

        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
          <.form for={@form} phx-submit="reset_password" class="space-y-6">
            <div>
              <label for="user_password" class="block text-sm font-semibold text-gray-700 mb-2">
                New Password
              </label>
              <div class="relative">
                <input
                  id="user_password"
                  name="user[password]"
                  type={if @show_password, do: "text", else: "password"}
                  required
                  disabled={@submitting}
                  placeholder="••••••••••••"
                  class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed"
                />
                <button
                  type="button"
                  phx-click="show_password"
                  disabled={@submitting}
                  class="absolute right-3 top-3 text-gray-500 hover:text-gray-700 disabled:opacity-50"
                >
                  <%= if @show_password do %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
                      />
                    </svg>
                  <% else %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                      />
                    </svg>
                  <% end %>
                </button>
              </div>
            </div>

            <div>
              <label for="user_password_confirmation" class="block text-sm font-semibold text-gray-700 mb-2">
                Confirm Password
              </label>
              <input
                id="user_password_confirmation"
                name="user[password_confirmation]"
                type={if @show_password, do: "text", else: "password"}
                required
                disabled={@submitting}
                placeholder="••••••••••••"
                class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed"
              />
            </div>

            <div class="text-sm text-gray-600">
              <p class="mb-2">Password requirements:</p>
              <ul class="list-disc list-inside space-y-1 text-gray-600">
                <li>At least 8 characters long</li>
                <li>Mix of upper and lowercase letters</li>
                <li>At least one number</li>
                <li>At least one special character</li>
              </ul>
            </div>

            <%= if @error_message do %>
              <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
                <%= @error_message %>
              </div>
            <% end %>

            <div>
              <button
                type="submit"
                disabled={@submitting}
                class="w-full bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
              >
                <%= if @submitting do %>
                  <svg
                    class="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  Resetting Password...
                <% else %>
                  Reset Password
                <% end %>
              </button>
            </div>
          </.form>

          <div class="mt-6 text-center text-sm">
            <a href={~p"/"} class="text-indigo-600 hover:text-indigo-700 font-medium">
              Back to Login
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
