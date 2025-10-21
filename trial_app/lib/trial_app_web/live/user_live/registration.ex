defmodule TrialAppWeb.UserLive.Registration do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Start with empty form
    form_data = %{"email" => "", "password" => "", "password_confirmation" => ""}
    {:ok, assign(socket,
      form: to_form(form_data, as: "user"),
      loading: false,
      error: nil,
      password_match: true
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

    # Validate all fields
    errors = []

    # Email validation
    if user_params["email"] == "" do
      errors = errors ++ ["Email is required"]
    else
      unless String.contains?(user_params["email"], "@") do
        errors = errors ++ ["Please enter a valid email address"]
      end
    end

    # Password validation
    if user_params["password"] == "" do
      errors = errors ++ ["Password is required"]
    else
      if String.length(user_params["password"]) < 6 do
        errors = errors ++ ["Password must be at least 6 characters"]
      end
    end

    # Password confirmation validation
    if user_params["password_confirmation"] == "" do
      errors = errors ++ ["Please confirm your password"]
    else
      if user_params["password"] != user_params["password_confirmation"] do
        errors = errors ++ ["Passwords don't match"]
      end
    end

    if Enum.empty?(errors) do
      # Success - redirect to login
      {:noreply,
       socket
       |> put_flash(:info, "Account created successfully! You can now login.")
       |> push_navigate(to: "/users/login")}
    else
      # Show errors but KEEP the form data
      error_message = Enum.join(errors, ", ")
      {:noreply, assign(socket,
        loading: false,
        error: error_message,
        form: to_form(user_params, as: "user")
      )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-100 via-pink-100 to-blue-100 flex items-center justify-center p-6">
      <div class="max-w-md w-full">
        <div class="bg-white rounded-2xl shadow-2xl p-8">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-gray-800 mb-2">Create Account</h1>
            <p class="text-gray-600">Join us today! It's free 🎉</p>
          </div>

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
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
              />
            </div>

            <!-- Password Field -->
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                🔒 Password
              </label>
              <input
                type="password"
                name="user[password]"
                value={@form[:password].value}
                required
                placeholder="••••••••"
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all"
              />
              <p class="mt-1 text-xs text-gray-500">Must be at least 6 characters</p>
            </div>

            <!-- Confirm Password Field -->
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                🔒 Confirm Password
              </label>
              <input
                type="password"
                name="user[password_confirmation]"
                value={@form[:password_confirmation].value}
                required
                placeholder="••••••••"
                class={"w-full px-4 py-3 border-2 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all #{if !@password_match && @form[:password_confirmation].value != "", do: "border-red-300 bg-red-50", else: "border-gray-300"}"}
              />
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
