defmodule TrialAppWeb.UserLive.ForgotPassword do
  use TrialAppWeb, :live_view

  alias TrialApp.Accounts
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       email: "",
       submitted: false,
       error_message: nil,
       submitting: false
     )}
  end

  @impl true
  def handle_event("send_reset_link", %{"email" => email}, socket) do
    Logger.info("Forgot password request for email: #{email}")

    # Send the reset email in the background
    send(self(), {:send_reset_email, email})

    # Always show success message (security best practice - don't reveal if email exists)
    {:noreply,
     assign(socket,
       submitted: true,
       email: email,
       submitting: true
     )}
  end

  @impl true
  def handle_info({:send_reset_email, email}, socket) do
    case Accounts.get_user_by_email(email) do
      nil ->
        # Don't reveal that user doesn't exist
        Logger.info("Password reset requested for non-existent email: #{email}")
        :ok

      user ->
        # Generate token and send email
        token = Accounts.generate_force_reset_token(user)
        reset_url = url(~p"/users/reset-password/#{token}")

        Task.start(fn ->
          try do
            Accounts.deliver_reset_password_instructions(user, reset_url)
            Logger.info("Password reset email sent to: #{email}")
          rescue
            e ->
              Logger.error("Failed to send reset email: #{inspect(e)}")
          end
        end)
    end

    {:noreply, assign(socket, submitting: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <div class="w-full max-w-md">
        <div class="text-center mb-8">
          <img src={~p"/images/value8-logo.png"} alt="Value8 Logo" class="h-10 mx-auto mb-6" />
          <h3 class="text-3xl font-semibold text-gray-800 mb-2">Forgot Password?</h3>
          <p class="text-gray-600">
            <%= if @submitted do %>
              Check your email for reset instructions
            <% else %>
              Enter your email to receive a password reset link
            <% end %>
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
          <%= if @submitted do %>
            <div class="space-y-4">
              <div class="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg text-sm">
                <p class="font-semibold mb-1">Email sent!</p>
                <p>
                  If an account exists for <strong><%= @email %></strong>, you will receive a password reset link shortly.
                </p>
              </div>

              <div class="text-sm text-gray-600 space-y-2">
                <p>Didn't receive the email?</p>
                <ul class="list-disc list-inside space-y-1">
                  <li>Check your spam folder</li>
                  <li>Verify the email address is correct</li>
                  <li>Wait a few minutes and try again</li>
                </ul>
              </div>

              <div class="flex gap-3">
                <a
                  href={~p"/"}
                  class="flex-1 text-center bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 transition"
                >
                  Back to Login
                </a>
                <button
                  phx-click="send_reset_link"
                  phx-value-email={@email}
                  disabled={@submitting}
                  class="flex-1 bg-gray-200 text-gray-700 font-semibold py-3 px-4 rounded-lg hover:bg-gray-300 transition disabled:opacity-50"
                >
                  Resend Email
                </button>
              </div>
            </div>
          <% else %>
            <form phx-submit="send_reset_link" class="space-y-6">
              <div>
                <label for="email" class="block text-sm font-semibold text-gray-700 mb-2">
                  Email Address
                </label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  required
                  disabled={@submitting}
                  value={@email}
                  placeholder="your.email@example.com"
                  class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900 disabled:opacity-50"
                />
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
                    Sending...
                  <% else %>
                    Send Reset Link
                  <% end %>
                </button>
              </div>
            </form>

            <div class="mt-6 text-center text-sm">
              <a href={~p"/"} class="text-indigo-600 hover:text-indigo-700 font-medium">
                Back to Login
              </a>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
