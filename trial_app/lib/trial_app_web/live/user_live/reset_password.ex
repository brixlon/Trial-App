defmodule TrialAppWeb.UserLive.ResetPassword do
  use TrialAppWeb, :live_view
  alias TrialApp.Accounts

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => ""}, as: "user")
    {:ok, assign(socket, form: form)}
  end

  def handle_event("send_reset", %{"user" => %{"email" => email}}, socket) do
    # You'll need to implement the actual password reset token generation
    # For now, we'll just show a success message

    # In a real implementation, you would:
    # 1. Generate a password reset token
    # 2. Send an email with the reset link
    # Accounts.deliver_user_reset_password_instructions(user, &url(~p"/users/reset-password/#{&1}"))

    {:noreply,
     socket
     |> put_flash(:info, "If an account exists with that email, you will receive password reset instructions.")
     |> push_navigate(to: ~p"/users/login")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <!-- Left Side - Image Slider with Text Overlay -->
      <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden">
        <!-- Sliding Background Images -->
        <div class="absolute inset-0">
          <div class="slide-container">
            <div class="slide">
              <img
                src="https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=1200&auto=format&fit=crop&q=80"
                alt="Team collaboration"
                class="w-full h-full object-cover"
              />
            </div>
            <div class="slide">
              <img
                src="https://images.unsplash.com/photo-1553877522-43269d4ea984?w=1200&auto=format&fit=crop&q=80"
                alt="Professional workplace"
                class="w-full h-full object-cover"
              />
            </div>
            <div class="slide">
              <img
                src="https://images.unsplash.com/photo-1600880292203-757bb62b4baf?w=1200&auto=format&fit=crop&q=80"
                alt="Business meeting"
                class="w-full h-full object-cover"
              />
            </div>
          </div>
        </div>

        <!-- Bottom gradient overlay for text -->
        <div class="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/70"></div>

        <!-- Text at bottom -->
        <div class="absolute bottom-0 left-0 right-0 p-12 text-white z-10">
          <h2 class="text-4xl font-bold mb-4">
            Trial Management System
          </h2>
          <p class="text-xl font-light">
            DIGITIZING YOUR WORKFLOW.
          </p>
        </div>
      </div>

      <!-- Right Side - Reset Password Form -->
      <div class="flex-1 flex items-center justify-center p-8 bg-gray-50">
        <div class="w-full max-w-md">
          <!-- Logo -->
          <div class="text-center mb-8">
            <div class="h-10 mx-auto mb-6 text-indigo-600 text-2xl font-bold">
              TrialApp
            </div>
            <h3 class="text-3xl font-semibold text-gray-800 mb-2">Reset Password</h3>
            <p class="text-gray-600">Enter your email to receive reset instructions</p>
          </div>

          <!-- Flash Messages -->
          <%= if @flash["info"] do %>
            <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-green-500 text-lg mr-2">✅</span>
                <p class="text-green-700 font-semibold"><%= @flash["info"] %></p>
              </div>
            </div>
          <% end %>

          <%= if @flash["error"] do %>
            <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl">
              <div class="flex items-center">
                <span class="text-red-500 text-lg mr-2">⚠️</span>
                <p class="text-red-700 font-semibold"><%= @flash["error"] %></p>
              </div>
            </div>
          <% end %>

          <!-- Reset Password Form -->
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
            <.form for={@form} phx-submit="send_reset" class="space-y-6">
              <!-- Email Field -->
              <div>
                <label for="user_email" class="block text-sm font-semibold text-gray-700 mb-2">
                  Employee Email
                </label>
                <input
                  id="user_email"
                  name="user[email]"
                  type="email"
                  autocomplete="email"
                  required
                  placeholder="your.email@company.com"
                  class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition text-gray-900"
                />
              </div>

              <!-- Submit Button -->
              <div>
                <button
                  type="submit"
                  class="w-full bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition"
                >
                  Send Reset Instructions
                </button>
              </div>

              <!-- Back to Login -->
              <div class="text-center">
                <.link
                  navigate={~p"/users/login"}
                  class="text-sm font-medium text-indigo-600 hover:text-indigo-700 transition"
                >
                  ← Back to Login
                </.link>
              </div>
            </.form>
          </div>

          <!-- Footer -->
          <div class="mt-8 text-center text-sm text-gray-600">
            <div class="flex items-center justify-center gap-2 mb-2">
              <span>Powered by TrialApp</span>
            </div>
            <div class="flex items-center justify-center gap-4 text-gray-500">
              <a href="mailto:support@trialapp.com" class="hover:text-gray-700 flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
                support@trialapp.com
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>

    <style>
      .slide-container {
        position: relative;
        width: 100%;
        height: 100%;
        overflow: hidden;
      }

      .slide {
        position: absolute;
        inset: 0;
        opacity: 0;
        animation: slideShow 18s infinite;
      }

      /* First slide: show immediately */
      .slide:first-child {
        opacity: 1;
        animation-delay: 0s;
      }

      .slide:nth-child(2) { animation-delay: 6s; }
      .slide:nth-child(3) { animation-delay: 12s; }

      @keyframes slideShow {
        0%, 28% { opacity: 1; }
        33%, 61% { opacity: 1; }
        66%, 100% { opacity: 0; }
      }

      .slide img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        filter: brightness(0.85);
        animation: kenburns 18s ease-in-out infinite;
      }

      @keyframes kenburns {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.08); }
      }
    </style>
    """
  end
end
