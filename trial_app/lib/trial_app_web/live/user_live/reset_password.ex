defmodule TrialAppWeb.UserLive.ResetPassword do
  use TrialAppWeb, :live_view

  alias TrialApp.Accounts

  @impl true
  @impl true
@impl true
def mount(%{"token" => token}, _session, socket) do
  case Accounts.verify_force_reset_token(token) do
    %Accounts.User{} = user ->
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
         show_password: false
       )}

    nil ->
      form =
        Phoenix.Component.to_form(
          %{"password" => "", "password_confirmation" => ""},
          as: "user"
        )

      {:ok,
       socket
       |> put_flash(:error, "Invalid or expired reset token")
       |> assign(
         form: form,
         user: nil,
         token: token,
         error_message: nil,
         show_password: false
       )}
  end
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
                <input id="user_password"
                       name="user[password]"
                       type={if @show_password, do: "text", else: "password"}
                       required
                       placeholder="••••••••••••"
                       class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900" />
                <button type="button"
                        phx-click="show_password"
                        class="absolute right-3 top-3 text-gray-500 hover:text-gray-700">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
              </div>
            </div>

            <div>
              <label for="user_password_confirmation" class="block text-sm font-semibold text-gray-700 mb-2">
                Confirm Password
              </label>
              <input id="user_password_confirmation"
                     name="user[password_confirmation]"
                     type={if @show_password, do: "text", else: "password"}
                     required
                     placeholder="••••••••••••"
                     class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900" />
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
              <div class="text-red-500 text-sm text-center"><%= @error_message %></div>
            <% end %>

            <div>
              <button type="submit"
                      class="w-full bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition">
                Reset Password
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
