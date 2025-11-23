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

    # Attach logo as inline image
    logo_path = Application.app_dir(:trial_app, "priv/static/images/value8-logo.png")

    email =
      if File.exists?(logo_path) do
        attachment =
          logo_path
          |> Swoosh.Attachment.new(filename: "logo.png", type: :inline)
          |> Map.put(:content_id, "logo.png")

        email |> attachment(attachment)
      else
        email
      end

    email = if html_body, do: html_body(email, html_body), else: email

    # Deliver the email - Mailer.deliver expects the email struct directly
    Mailer.deliver(email)
  end

  defp logo_html do
    "<img src=\"cid:logo.png\" alt=\"Value8\" style=\"display: block; margin: 0 auto 15px auto; width: 80px; height: auto;\" />"
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
            .header { background-color: #4F46E5; color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              #{logo_html()}
              <h1 style="margin: 0;">Update Email Address</h1>
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

  @doc """
  Deliver welcome email to new attachee with secure password reset link.
  """
  def deliver_attachee_welcome_email(user, _password) do
    # === 1. Set must_change_password flag ===
    user
    |> Ecto.Changeset.change(%{must_change_password: true})
    |> TrialApp.Repo.update!()

    # === 2. Generate secure token ===
    token = TrialApp.Accounts.generate_force_reset_token(user)

    # === 3. Build secure URL with token ===
    url = Phoenix.VerifiedRoutes.unverified_url(
      TrialAppWeb.Endpoint,
      "/users/force-reset/#{token}"
    )

    # Get a friendly name - prefer first_name, fall back to username
    name =
      cond do
        user.first_name && String.trim(user.first_name) != "" ->
          user.first_name |> String.split() |> List.first()

        user.username && String.trim(user.username) != "" ->
          user.username

        true ->
          user.email |> String.split("@") |> List.first()
      end

    deliver(
      user.email,
      "Welcome to Value8 - Set Your Password",
      """
      ==============================

      Hi #{name},

      Welcome to Value8! Your account has been created.

      For your security, you must set your own password before accessing the system.

      Please click the link below to set your new password:
      #{url}

      SECURITY NOTICE:
      - This link expires in 24 hours
      - Do not share this link with anyone
      - You will be logged in automatically after setting your password
      - If the link expires, contact your supervisor for a new one

      ==============================
      """,
      """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #4F46E5; color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
            .credentials { background-color: #fff; padding: 15px; border-radius: 4px; border: 1px solid #e5e7eb; margin: 20px 0; }
            .security-note { background-color: #FFFBEB; border: 1px solid #FCD34D; padding: 15px; border-radius: 6px; margin: 15px 0; }
            .security-note strong { color: #D97706; }
            ul { margin: 10px 0; padding-left: 20px; }
            li { margin-bottom: 5px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              #{logo_html()}
              <h1 style="margin: 0;">Welcome to Value8!</h1>
            </div>
            <div class="content">
              <p>Hi #{name},</p>
              <p>Your account has been successfully created. We're excited to have you on board!</p>

              <div class="security-note">
                <strong>🔒 Security First:</strong> For your protection, you must set your own password before accessing the system.
              </div>

              <p style="text-align: center;">
                <a href="#{url}" class="button">Set Your Password</a>
              </p>

              <div class="credentials">
                <p><strong>⚠️ Security Notice:</strong></p>
                <ul>
                  <li>This link expires in <strong>24 hours</strong></li>
                  <li>Do not share this link with anyone</li>
                  <li>You will be logged in automatically after setting your password</li>
                  <li>If the link expires, contact your supervisor for a new one</li>
                </ul>
              </div>

              <p style="font-size: 12px; color: #666;">If the button doesn't work, copy and paste this link into your browser:<br>
              <span style="word-break: break-all; color: #4F46E5;">#{url}</span></p>
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
  Deliver welcome email with credentials to new user (alias for deliver_attachee_welcome_email).
  """
  def deliver_user_credentials(user, password) do
    deliver_attachee_welcome_email(user, password)
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
            .header { background-color: #4F46E5; color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              #{logo_html()}
              <h1 style="margin: 0;">Confirm Your Account</h1>
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
            .header { background-color: #4F46E5; color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .button { display: inline-block; background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              #{logo_html()}
              <h1 style="margin: 0;">Reset Your Password</h1>
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
            .header { background-color: #10B981; color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
            .alert { background-color: #FEF3C7; border-left: 4px solid #F59E0B; padding: 12px; margin: 20px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              #{logo_html()}
              <h1 style="margin: 0;">✓ Password Reset Successful</h1>
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
