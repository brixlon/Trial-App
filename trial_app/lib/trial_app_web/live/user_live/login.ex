defmodule TrialAppWeb.UserLive.Login do
  use TrialAppWeb, :live_view

  alias TrialApp.Accounts
  alias TrialApp.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")
    {:ok, assign(socket, form: form, error_message: nil)}
  end

  @impl true
  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:noreply, assign(socket, :error_message, "Invalid email or password")}

      %User{} = user ->
        cond do
          user.must_change_password ->
            {:noreply,
             push_redirect(socket,
               to: ~p"/users/force_password_change?user_id=#{user.id}"
             )}

          user.status != "active" ->
            {:noreply,
             assign(socket, :error_message, "Your account is inactive. Contact admin.")}

          true ->
            # This goes to a controller that sets the session, then redirects to dashboard.
            {:noreply, redirect(socket, to: ~p"/users/login?user_id=#{user.id}")}
        end
    end
  end

  @impl true
  def handle_event("forgot_password", _params, socket) do
    {:noreply, push_redirect(socket, to: ~p"/users/reset_password")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <!-- Left Side - Image Slider -->
      <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden">
        <div class="absolute inset-0">
          <div class="slide-container">
            <div class="slide">
              <img src="https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=1200&auto=format&fit=crop&q=80"
                   alt="Team collaboration"
                   class="w-full h-full object-cover" />
            </div>
            <div class="slide">
              <img src="https://images.unsplash.com/photo-1553877522-43269d4ea984?w=1200&auto=format&fit=crop&q=80"
                   alt="Professional workplace"
                   class="w-full h-full object-cover" />
            </div>
            <div class="slide">
              <img src="https://images.unsplash.com/photo-1600880292203-757bb62b4baf?w=1200&auto=format&fit=crop&q=80"
                   alt="Business meeting"
                   class="w-full h-full object-cover" />
            </div>
          </div>
        </div>

        <div class="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/70"></div>
        <div class="absolute bottom-0 left-0 right-0 p-12 text-white z-10">
          <h2 class="text-4xl font-bold mb-4">Attachment Management System</h2>
          <p class="text-xl font-light">DIGITIZING YOUR WORKFLOW.</p>
        </div>
      </div>

      <!-- Right Side - Login Form -->
      <div class="flex-1 flex items-center justify-center p-8 bg-gray-50">
        <div class="w-full max-w-md">
          <div class="text-center mb-8">
            <img src={~p"/images/logo.png"} alt="Value8 Logo" class="h-10 mx-auto mb-6" />
            <h3 class="text-3xl font-semibold text-gray-800 mb-2">Sign In</h3>
            <p class="text-gray-600">Welcome back. Let's get you signed in</p>
          </div>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
            <.form for={@form} phx-submit="login" class="space-y-6">
              <div>
                <label for="user_email" class="block text-sm font-semibold text-gray-700 mb-2">
                  Employee Email
                </label>
                <input id="user_email"
                       name="user[email]"
                       type="email"
                       autocomplete="email"
                       required
                       placeholder="your.email@company.com"
                       class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900" />
              </div>

              <div>
                <label for="user_password" class="block text-sm font-semibold text-gray-700 mb-2">
                  Password
                </label>
                <div class="relative">
                  <input id="user_password"
                         name="user[password]"
                         type="password"
                         autocomplete="current-password"
                         required
                         placeholder="••••••••••••"
                         class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900" />
                </div>
              </div>

              <%= if @error_message do %>
                <div class="text-red-500 text-sm text-center"><%= @error_message %></div>
              <% end %>

              <div class="text-left">
                <a href="#" phx-click="forgot_password" class="text-sm font-medium text-indigo-600 hover:text-indigo-700 transition">
                  Forgot Password?
                </a>
              </div>

              <div>
                <button type="submit"
                        class="w-full bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition">
                  Continue
                </button>
              </div>
            </.form>
          </div>

          <div class="mt-8 text-center text-sm text-gray-600">
            <div class="flex items-center justify-center gap-2 mb-2">
              <span>Powered by</span>
              <img src={~p"/images/logo.png"} alt="Value8" class="h-5" />
            </div>
            <div class="flex items-center justify-center gap-4 text-gray-500">
              <a href="mailto:info@valuechainfactory.com" class="hover:text-gray-700 flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                info@valuechainfactory.com
              </a>
              <a href="tel:02079030025" class="hover:text-gray-700 flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                </svg>
                020 7903025
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>

    <style>
      .slide-container { position: relative; width: 100%; height: 100%; overflow: hidden; }
      .slide { position: absolute; inset: 0; opacity: 0; animation: slideShow 18s infinite; }
      .slide:first-child { opacity: 1; animation-delay: 0s; }
      .slide:nth-child(2) { animation-delay: 6s; }
      .slide:nth-child(3) { animation-delay: 12s; }
      @keyframes slideShow {
        0%, 28% { opacity: 1; }
        33%, 61% { opacity: 1; }
        66%, 100% { opacity: 0; }
      }
      .slide img {
        width: 100%; height: 100%; object-fit: cover; filter: brightness(0.85);
        animation: kenburns 18s ease-in-out infinite;
      }
      @keyframes kenburns { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.08); } }
    </style>
    """
  end
end
