defmodule TrialAppWeb.UserLive.Login do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")
    {:ok, assign(socket, form: form, error: nil, loading: false)}
  end

  def handle_event("login", %{"user" => user_params}, socket) do
    socket = assign(socket, loading: true, error: nil)

    case authenticate_user(user_params["email"], user_params["password"]) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back, #{user.email}!")
         |> push_navigate(to: "/dashboard")}

      {:error, message} ->
        {:noreply, assign(socket, error: message, loading: false)}
    end
  end

  # Mock authentication
  defp authenticate_user("test@test.com", "password"), do: {:ok, %{email: "test@test.com"}}
  defp authenticate_user("", _), do: {:error, "Please enter your email"}
  defp authenticate_user(_, ""), do: {:error, "Please enter your password"}
  defp authenticate_user(_email, _password), do: {:error, "Invalid email or password"}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-100 via-purple-100 to-pink-100 flex items-center justify-center p-6">
      <div class="max-w-md w-full">
        <div class="bg-white rounded-2xl shadow-2xl p-8">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-gray-800 mb-2">Welcome Back!</h1>
            <p class="text-gray-600">Sign in to your account 🔐</p>
          </div>

          <.form for={@form} phx-submit="login" class="space-y-6">
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
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
              />
            </div>

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
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
              />
            </div>

            <div class="flex items-center justify-between">
              <label class="flex items-center">
                <input
                  type="checkbox"
                  name="user[remember_me]"
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <span class="ml-2 text-sm text-gray-600">Remember me</span>
              </label>

              <.link navigate="/users/register" class="text-sm text-blue-600 hover:text-blue-700 font-semibold">
                Forgot password?
              </.link>
            </div>

            <button
              type="submit"
              disabled={@loading}
              class="w-full flex items-center justify-center gap-2 px-6 py-4 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-xl hover:from-blue-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
            >
              <%= if @loading do %>
                <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Signing in...
              <% else %>
                🚀 Sign In
              <% end %>
            </button>
          </.form>

          <%= if @error do %>
            <div class="mt-4 p-4 bg-red-50 border border-red-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-red-500 text-lg mr-2">⚠️</span>
                <p class="text-red-700 font-semibold"><%= @error %></p>
              </div>
            </div>
          <% end %>

          <div class="mt-6 text-center">
            <p class="text-gray-600">
              Don't have an account?
              <.link navigate="/users/register" class="text-blue-600 font-semibold hover:text-blue-700">
                Create one here
              </.link>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
