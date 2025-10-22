defmodule TrialAppWeb.DashboardLive do
  use TrialAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-2xl shadow-2xl p-8">
          <div class="flex items-center justify-between mb-8">
            <div>
              <h1 class="text-4xl font-bold text-gray-800 mb-2">
                Welcome, {@current_scope.user.username}!
              </h1>
              <p class="text-gray-600">You're successfully logged in!</p>
            </div>

            <.link
              href="/users/logout"
              method="delete"
              class="px-6 py-3 bg-red-600 hover:bg-red-700 text-white font-semibold rounded-xl transition-all shadow-lg"
            >
              🚪 Logout
            </.link>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 text-white">
              <div class="text-5xl mb-2">👤</div>
              <h3 class="text-xl font-bold mb-1">Your Profile</h3>
              <p class="text-blue-100">Manage your account</p>
            </div>

            <.link
              navigate="/users/settings"
              class="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl p-6 text-white hover:from-purple-600 hover:to-purple-700 transition-all duration-300 cursor-pointer block"
            >
              <div class="text-5xl mb-2">⚙️</div>
              <h3 class="text-xl font-bold mb-1">Settings</h3>
              <p class="text-purple-100">Configure preferences</p>
            </.link>

            <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white">
              <div class="text-5xl mb-2">📊</div>
              <h3 class="text-xl font-bold mb-1">Analytics</h3>
              <p class="text-green-100">View your stats</p>
            </div>
          </div>

          <div class="bg-gray-50 rounded-xl p-6">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">Account Information</h2>
            <div class="space-y-3">
            <div class="flex items-center gap-3">
                <span class="text-gray-600 font-semibold w-32">Username:</span>
                <span class="text-gray-800">{@current_scope.user.username}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-gray-600 font-semibold w-32">Email:</span>
                <span class="text-gray-800">{@current_scope.user.email}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-gray-600 font-semibold w-32">Account ID:</span>
                <span class="text-gray-800">{@current_scope.user.id}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-gray-600 font-semibold w-32">Status:</span>
                <span class="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-semibold">
                  ✓ Active
                </span>
              </div>
            </div>
          </div>

          <div class="mt-8 p-6 bg-blue-50 rounded-xl border-2 border-blue-200">
            <h3 class="text-lg font-bold text-blue-900 mb-2">🎓 Learning Authentication</h3>
            <p class="text-blue-800">
              This is a protected page! Only logged-in users can see this content.
              Try logging out and accessing this page - you'll be redirected to login!
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
