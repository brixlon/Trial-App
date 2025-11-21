defmodule TrialApp.Accounts.UserNotifier do
  import Swoosh.Email

  alias TrialApp.Mailer
  alias TrialApp.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body, html_body \\ nil) do
    # Get the configured sender email from application config
    mailer_config = Application.get_env(:trial_app, TrialApp.Mailer, [])
    sender_email = Keyword.get(mailer_config, :username, "mutindasam39@gmail.com")

    email =
      new()
      |> to(recipient)
      |> from({"Value8", sender_email})
      |> subject(subject)
      |> text_body(body)

    email = if html_body, do: html_body(email, html_body), else: email

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Update email instructions",
      """
      ==============================

      Hi #{user.email},

      You can change your email by visiting the URL below:

      #{url}

      If you didn't request this change, please ignore this.

      ==============================
      """,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #4F46E5; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Update Email Address</h1>
            </div>
            <div class="content">
              <p>Hi #{user.email},</p>
              <p>You can change your email by clicking the button below:</p>
              <p style="text-align: center;">
                <a href="#{url}" class="button">Update Email</a>
              </p>
              <p>Or copy and paste this link into your browser:</p>
              <p style="word-break: break-all; color: #4F46E5;">#{url}</p>
              <p>If you didn't request this change, please ignore this email.</p>
            </div>
            <div class="footer">
              <p>© #{DateTime.utc_now().year} Value8. All rights reserved.</p>
            </div>
          </div>
        </body>
      </html>
      """
    )
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
    deliver(
      user.email,
      "Log in instructions",
      """
      ==============================

      Hi #{user.email},

      You can log into your account by visiting the URL below:

      #{url}

      If you didn't request this email, please ignore this.

      ==============================
      """
    )
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(
      user.email,
      "Confirmation instructions",
      """
      ==============================

      Hi #{user.email},

      You can confirm your account by visiting the URL below:

      #{url}

      If you didn't create an account with us, please ignore this.

      ==============================
      """,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #4F46E5; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Confirm Your Account</h1>
            </div>
            <div class="content">
              <p>Hi #{user.email},</p>
              <p>You can confirm your account by clicking the button below:</p>
              <p style="text-align: center;">
                <a href="#{url}" class="button">Confirm Account</a>
              </p>
              <p>Or copy and paste this link into your browser:</p>
              <p style="word-break: break-all; color: #4F46E5;">#{url}</p>
              <p>If you didn't create an account with us, please ignore this email.</p>
            </div>
            <div class="footer">
              <p>© #{DateTime.utc_now().year} Value8. All rights reserved.</p>
            </div>
          </div>
        </body>
      </html>
      """
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(
      user.email,
      "Reset your password",
      """
      ==============================

      Hi #{user.email},

      You requested to reset your password. Click the link below to set a new password:

      #{url}

      This link will expire in 24 hours.

      If you didn't request a password reset, please ignore this email.

      ==============================
      """,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #4F46E5; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Reset Your Password</h1>
            </div>
            <div class="content">
              <p>Hi #{user.email},</p>
              <p>You requested to reset your password. Click the button below to set a new password:</p>
              <p style="text-align: center;">
                <a href="#{url}" class="button">Reset Password</a>
              </p>
              <p>Or copy and paste this link into your browser:</p>
              <p style="word-break: break-all; color: #4F46E5;">#{url}</p>
              <p><strong>This link will expire in 24 hours.</strong></p>
              <p>If you didn't request a password reset, please ignore this email.</p>
            </div>
            <div class="footer">
              <p>© #{DateTime.utc_now().year} Value8. All rights reserved.</p>
            </div>
          </div>
        </body>
      </html>
      """
    )
  end

  @doc """
  Deliver confirmation that password was reset successfully.
  """
  def deliver_password_reset_confirmation(user) do
    deliver(
      user.email,
      "Your password has been reset",
      """
      ==============================

      Hi #{user.email},

      Your password has been successfully reset.

      If you didn't make this change, please contact support immediately.

      ==============================
      """,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #10B981; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
            .alert { background-color: #FEF3C7; border-left: 4px solid #F59E0B; padding: 12px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>✓ Password Reset Successful</h1>
            </div>
            <div class="content">
              <p>Hi #{user.email},</p>
              <p>Your password has been successfully reset at #{DateTime.utc_now() |> Calendar.strftime("%B %d, %Y at %I:%M %p UTC")}.</p>
              <div class="alert">
                <strong>⚠️ Security Notice:</strong> If you didn't make this change, please contact support immediately.
              </div>
              <p>You can now log in to your account using your new password.</p>
              <p>Thank you for keeping your account secure!</p>
            </div>
            <div class="footer">
              <p>© #{DateTime.utc_now().year} Value8. All rights reserved.</p>
            </div>
          </div>
        </body>
      </html>
      """
    )
  end
end
