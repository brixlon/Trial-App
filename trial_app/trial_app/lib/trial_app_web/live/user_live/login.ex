defmodule TrialAppWeb.UserLive.Login do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"email_or_username" => "", "password" => ""}, as: "user")
    {:ok, assign(socket, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-100 via-purple-100 to-pink-100 flex items-center justify-center p-6">
      <div class="max-w-md w-full">
        <div class="bg-white rounded-2xl shadow-2xl p-8">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-gray-800 mb-2">Welcome Back!</h1>
            <p class="text-gray-600">Sign in to your account 🔐</p>
          </div>
          
    <!-- Flash Messages -->
          <%= if @flash[:info] do %>
            <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-green-500 text-lg mr-2">✅</span>
                <p class="text-green-700 font-semibold">{@flash[:info]}</p>
              </div>
            </div>
          <% end %>

          <%= if @flash[:error] do %>
            <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-red-500 text-lg mr-2">⚠️</span>
                <p class="text-red-700 font-semibold">{@flash[:error]}</p>
              </div>
            </div>
          <% end %>

          <.form for={@form} action={~p"/users/login"} method="post" class="space-y-6">
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-2">
                👤 Username or Email
              </label>
              <input
                type="text"
                name="user[email_or_username]"
                value={@form[:email_or_username].value}
                required
                placeholder="username or your@email.com"
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all text-gray-900 bg-white"
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
                class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all text-gray-900 bg-white"
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

              <.link
                navigate="/users/register"
                class="text-sm text-blue-600 hover:text-blue-700 font-semibold"
              >
                Forgot password?
              </.link>
            </div>

            <button
              type="submit"
              class="w-full flex items-center justify-center gap-2 px-6 py-4 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-xl hover:from-blue-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
            >
              🚀 Sign In
            </button>
          </.form>

          <div class="mt-6 text-center">
            <p class="text-gray-600">
              Don't have an account?
              <.link
                navigate="/users/register"
                class="text-blue-600 font-semibold hover:text-blue-700"
              >
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
