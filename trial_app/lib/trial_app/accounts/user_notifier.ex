defmodule TrialApp.Accounts.UserNotifier do
  import Swoosh.Email

  alias TrialApp.Mailer
  alias TrialApp.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"TrialApp", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver onboarding credentials to a newly created user.
  Sends email with login link and system-generated password.
  """
  def deliver_onboarding_credentials(user, password, url) do
    first_name = user.first_name || "User"
    last_name = user.last_name || ""
    name = if last_name != "", do: "#{first_name} #{last_name}", else: first_name

    deliver(user.email, "Welcome to the Attachment Program - Your Login Credentials", """

    ==============================

    Dear #{name},

    Your account has been created and you have been enrolled in the attachment program.

    Your login credentials are:

    Email: #{user.email}
    Password: #{password}

    Please log in using the link below:

    #{url}

    For security reasons, please change your password after your first login.

    If you have any questions, please contact your administrator.

    ==============================
    """)
  end
end
