defmodule TrialAppWeb.ForcePasswordResetLive do
  use TrialAppWeb, :live_view
  alias TrialApp.{Accounts, Repo}

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.verify_force_reset_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid or expired password reset link.")
         |> push_navigate(to: ~p"/")}

      user ->
        changeset = Accounts.change_user_password(user)

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:token, token)
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_password(socket.assigns.user, user_params) do
      {:ok, result} ->
        # Handle different return formats from update_user_password
        user = case result do
          {user_struct, _tokens} when is_struct(user_struct) -> user_struct
          user_struct when is_struct(user_struct) -> user_struct
          _ ->
            # If we get :ok or something unexpected, reload the user from DB
            Repo.get!(TrialApp.Accounts.User, socket.assigns.user.id)
        end

        # Update authenticated_at, status to active, and must_change_password to false
        case user
             |> Ecto.Changeset.change(%{
               authenticated_at: DateTime.utc_now() |> DateTime.truncate(:second),
               must_change_password: false,
               status: "active"
             })
             |> Repo.update() do
          {:ok, updated_user} ->
            token = Accounts.generate_user_session_token(updated_user)
            # URL-encode the binary token for safe transmission in URLs
            encoded_token = Base.url_encode64(token, padding: false)

            {:noreply,
             socket
             |> put_flash(:info, "Password set successfully! Welcome!")
             |> redirect(to: ~p"/?user_token=#{encoded_token}")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to update user session")
             |> assign(form: to_form(socket.assigns.changeset))}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-indigo-100 via-purple-50 to-pink-100 p-4">
      <div class="w-full max-w-md">
        <div class="bg-white rounded-2xl shadow-xl p-8">
          <div class="text-center mb-8">
            <div class="mx-auto w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mb-4">
              <svg
                class="w-8 h-8 text-yellow-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                />
              </svg>
            </div>
            <h2 class="text-3xl font-bold text-gray-900 mb-2">Set Your Password</h2>
            <p class="text-gray-600">
              Welcome! Please create a secure password to access your account.
            </p>
          </div>

          <.form
            for={@form}
            as={:user}
            phx-change="validate"
            phx-submit="save"
            class="space-y-6"
          >
            <.input
              field={@form[:password]}
              type="password"
              label="New Password"
              required
              phx-debounce="blur"
              class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition"
            />

            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm Password"
              required
              phx-debounce="blur"
              class="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition"
            />

            <div class="bg-blue-50 border border-blue-200 text-blue-700 px-4 py-3 rounded-lg text-sm">
              <strong>Password Requirements:</strong>
              <ul class="list-disc list-inside mt-2 space-y-1">
                <li>At least 8 characters long</li>
                <li>Mix of letters and numbers recommended</li>
                <li>Avoid common passwords</li>
              </ul>
            </div>

            <.button
              phx-disable-with="Saving..."
              class="w-full bg-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition"
            >
              Set Password & Log In
            </.button>
          </.form>
        </div>

        <p class="text-center text-sm text-gray-600 mt-6">
          Need help? Contact your administrator
        </p>
      </div>
    </div>
    """
  end
end
