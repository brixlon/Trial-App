defmodule TrialAppWeb.UserLive.Settings do
  use TrialAppWeb, :live_view

  on_mount {TrialAppWeb.UserAuth, :require_authenticated}

  alias TrialApp.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-green-100 via-blue-100 to-purple-100 p-6">
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-2xl shadow-2xl p-8">
          <div class="text-center mb-8">
            <h1 class="text-4xl font-bold text-gray-800 mb-2">⚙️ Account Settings</h1>
            <p class="text-gray-600">Manage your account email address and password settings</p>
          </div>
          
    <!-- Email Settings Section -->
          <div class="mb-8 p-6 bg-gray-50 rounded-xl">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">📧 Email Settings</h2>
            <p class="text-gray-600 mb-4">
              Current email: <span class="font-semibold text-gray-800">{@current_email}</span>
            </p>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
              class="space-y-4"
            >
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  New Email Address
                </label>
                <input
                  type="email"
                  name="user[email]"
                  value={@email_form[:email].value}
                  placeholder="Enter new email address"
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all text-gray-900 bg-white"
                  required
                />
                <%= if @email_form[:email].errors != [] do %>
                  <div class="mt-1 text-sm text-red-600">
                    <%= for {msg, _} <- @email_form[:email].errors do %>
                      <p>{msg}</p>
                    <% end %>
                  </div>
                <% end %>
              </div>
              <button
                type="submit"
                class="px-6 py-3 bg-purple-600 text-white font-semibold rounded-xl hover:bg-purple-700 transition-all shadow-lg hover:shadow-xl"
              >
                📧 Change Email
              </button>
            </.form>
          </div>
          
    <!-- Password Settings Section -->
          <div class="p-6 bg-gray-50 rounded-xl">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">🔒 Password Settings</h2>
            <p class="text-gray-600 mb-4">Update your password to keep your account secure</p>

            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              class="space-y-4"
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                autocomplete="username"
                value={@current_email}
              />

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">New Password</label>
                <input
                  type="password"
                  name="user[password]"
                  value={@password_form[:password].value}
                  placeholder="Enter new password"
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all text-gray-900 bg-white"
                  required
                />
                <%= if @password_form[:password].errors != [] do %>
                  <div class="mt-1 text-sm text-red-600">
                    <%= for {msg, _} <- @password_form[:password].errors do %>
                      <p>{msg}</p>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Confirm New Password
                </label>
                <input
                  type="password"
                  name="user[password_confirmation]"
                  value={@password_form[:password_confirmation].value}
                  placeholder="Confirm new password"
                  class="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-all text-gray-900 bg-white"
                  required
                />
                <%= if @password_form[:password_confirmation].errors != [] do %>
                  <div class="mt-1 text-sm text-red-600">
                    <%= for {msg, _} <- @password_form[:password_confirmation].errors do %>
                      <p>{msg}</p>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <button
                type="submit"
                class="px-6 py-3 bg-green-600 text-white font-semibold rounded-xl hover:bg-green-700 transition-all shadow-lg hover:shadow-xl"
              >
                🔒 Save Password
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("lv:clear-flash", %{"key" => key}, socket) do
    {:noreply, clear_flash(socket, String.to_atom(key))}
  end
end
