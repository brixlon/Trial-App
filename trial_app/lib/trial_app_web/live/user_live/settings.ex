defmodule TrialAppWeb.UserLive.Settings do
  use TrialAppWeb, :live_view

  on_mount {TrialAppWeb.UserAuth, :require_authenticated}

  alias TrialApp.Accounts

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
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-gray-900">
      <div class="flex">
        <.live_component
          module={TrialAppWeb.SidebarComponent}
          id="sidebar"
          current_scope={@current_scope}
        />

        <main class="ml-64 w-full p-8">
          <div class="max-w-4xl mx-auto">
            <!-- Header -->
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-gray-900">Account Settings</h1>
              <p class="text-gray-600 mt-2">Manage your email and password settings</p>
            </div>

    <!-- Settings Grid -->
            <div class="grid grid-cols-1 gap-8">
              <!-- Email Settings -->
              <div class="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
                <h2 class="text-xl font-semibold text-gray-800 mb-4">Email Settings</h2>
                <p class="text-gray-600 mb-4 text-sm">
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
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      New Email Address
                    </label>
                    <input
                      type="email"
                      name="user[email]"
                      value={@email_form[:email].value}
                      placeholder="Enter new email address"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition text-gray-900 bg-white text-sm"
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
                    class="w-full px-4 py-2 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition text-sm"
                  >
                    Change Email
                  </button>
                </.form>
              </div>

    <!-- Password Settings -->
              <div class="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
                <h2 class="text-xl font-semibold text-gray-800 mb-4">Password Settings</h2>
                <p class="text-gray-600 mb-4 text-sm">
                  Update your password to keep your account secure
                </p>

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
                    <label class="block text-sm font-medium text-gray-700 mb-2">New Password</label>
                    <input
                      type="password"
                      name="user[password]"
                      value={@password_form[:password].value}
                      placeholder="Enter new password"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition text-gray-900 bg-white text-sm"
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
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Confirm New Password
                    </label>
                    <input
                      type="password"
                      name="user[password_confirmation]"
                      value={@password_form[:password_confirmation].value}
                      placeholder="Confirm new password"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition text-gray-900 bg-white text-sm"
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
                    class="w-full px-4 py-2 bg-green-600 text-white font-medium rounded-lg hover:bg-green-700 transition text-sm"
                  >
                    Save Password
                  </button>
                </.form>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
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
