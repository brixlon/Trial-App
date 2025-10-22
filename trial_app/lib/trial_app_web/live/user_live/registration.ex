defmodule TrialAppWeb.UserLive.Registration do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Start with empty form
    form_data = %{"email" => "", "password" => "", "password_confirmation" => ""}
    {:ok, assign(socket,
      form: to_form(form_data, as: "user"),
      loading: false,
      error: nil,
      password_match: true,
      show_password: false,
      show_confirm_password: false
    )}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    # Validate passwords match in real-time
    passwords_match = user_params["password"] == user_params["password_confirmation"]

    # Keep form data during validation
    form = to_form(user_params, as: "user")

    {:noreply, assign(socket,
      form: form,
      password_match: passwords_match,
      error: if(!passwords_match, do: "Passwords don't match", else: nil)
    )}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    socket = assign(socket, loading: true, error: nil)

    # Create user with proper validation
    case TrialApp.Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! Please log in.")
         |> push_navigate(to: "/users/login")}

      {:error, changeset} ->
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
          |> Enum.join(", ")

        {:noreply, assign(socket,
          loading: false,
          error: error_message,
          form: to_form(user_params, as: "user")
        )}
    end
  end

  def handle_event("toggle_password_visibility", _params, socket) do
    {:noreply, assign(socket, show_password: !socket.assigns.show_password)}
  end

  def handle_event("toggle_confirm_password_visibility", _params, socket) do
    {:noreply, assign(socket, show_confirm_password: !socket.assigns.show_confirm_password)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-100 via-pink-100 to-blue-100 flex items-center justify-center p-6">
      <div class="max-w-md w-full">
        <div class="bg-white rounded-2xl shadow-2xl p-8">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-gray-800 mb-2">Create Account</h1>
            <p class="text-gray-600">Join us today! It's free </p>
          </div>

          <!-- Flash Messages -->
          <%= if @flash[:info] do %>
            <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-green-500 text-lg mr-2">✅</span>
                <p class="text-green-700 font-semibold"><%= @flash[:info] %></p>
              </div>
            </div>
          <% end %>

          <%= if @flash[:error] do %>
            <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-red-500 text-lg mr-2">⚠️</span>
                <p class="text-red-700 font-semibold"><%= @flash[:error] %></p>
              </div>
            </div>
          <% end %>

          <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
            <!-- Email Field -->
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                📧 Email
              </label>
              <input
                type="email"
                name="user[email]"
                value={@form[:email].value}
                required
                placeholder="your@email.com"
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all text-gray-900 bg-white"
              />
            </div>

            <!-- Password Field -->
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                🔒 Password
              </label>
              <div class="relative">
                <input
                  type={if @show_password, do: "text", else: "password"}
                  name="user[password]"
                  value={@form[:password].value}
                  required
                  placeholder="••••••••"
                  class="w-full px-4 py-3 pr-12 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all text-gray-900 bg-white"
                />
                <button
                  type="button"
                  phx-click="toggle_password_visibility"
                  class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700 focus:outline-none"
                >
                  <%= if @show_password do %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>
                    </svg>
                  <% else %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                    </svg>
                  <% end %>
                </button>
              </div>
              <p class="mt-1 text-xs text-gray-500">Must be at least 6 characters</p>
            </div>

            <!-- Confirm Password Field -->
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                🔒 Confirm Password
              </label>
              <div class="relative">
                <input
                  type={if @show_confirm_password, do: "text", else: "password"}
                  name="user[password_confirmation]"
                  value={@form[:password_confirmation].value}
                  required
                  placeholder="••••••••"
                  class={"w-full px-4 py-3 pr-12 border-2 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all #{if !@password_match && @form[:password_confirmation].value != "", do: "border-red-300 bg-red-50", else: "border-gray-300"}"}
                />
                <button
                  type="button"
                  phx-click="toggle_confirm_password_visibility"
                  class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700 focus:outline-none"
                >
                  <%= if @show_confirm_password do %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"></path>
                    </svg>
                  <% else %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                    </svg>
                  <% end %>
                </button>
              </div>
              <%= if !@password_match && @form[:password_confirmation].value != "" do %>
                <p class="mt-1 text-sm text-red-600 flex items-center">
                  <span class="mr-1">⚠️</span> Passwords don't match
                </p>
              <% else %>
                <p class="mt-1 text-xs text-gray-500">Re-enter your password</p>
              <% end %>
            </div>

            <!-- Submit Button -->
            <button
              type="submit"
              disabled={@loading}
              class="w-full flex items-center justify-center gap-2 px-6 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-semibold rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
            >
              <%= if @loading do %>
                <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Creating Account...
              <% else %>
                ✨ Create Account
              <% end %>
            </button>
          </.form>

          <!-- Error Message -->
          <%= if @error do %>
            <div class="mt-4 p-4 bg-red-50 border border-red-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-red-500 text-lg mr-2">⚠️</span>
                <p class="text-red-700 font-semibold"><%= @error %></p>
              </div>
            </div>
          <% end %>

          <!-- Login Link -->
          <div class="mt-6 text-center">
            <p class="text-gray-600">
              Already have an account?
              <.link navigate="/users/login" class="text-purple-600 font-semibold hover:text-purple-700">
                Sign in here
              </.link>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
