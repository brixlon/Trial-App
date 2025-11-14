# lib/trial_app/emails.ex

defmodule TrialApp.Emails do
  @moduledoc """
  Delivers emails for the application.
  """
  import Swoosh.Email
  alias TrialApp.Mailer
  alias TrialApp.Accounts
  alias TrialApp.Repo

  @doc """
  Sends a secure welcome email to a newly created attachee with a force-reset password link.
  This function will send to the attachee's ACTUAL email address.
  """
  def send_attachee_welcome_email(attachee, _plain_password) do
    user = Repo.preload(attachee, :user).user
    email = user.email
    full_name = user.username || user.email

    # === 1. Set must_change_password flag ===
    user
    |> Ecto.Changeset.change(%{must_change_password: true})
    |> Repo.update!()

    # === 2. Generate secure magic link ===
    token = Accounts.generate_force_reset_token(user)
    reset_url = Phoenix.VerifiedRoutes.unverified_url(
      TrialAppWeb.Endpoint,
      "/users/force-reset/#{token}"
    )

    # === 3. Load org & dept info ===
    department = attachee.department
    organization = attachee.organization

    # === 4. Build and SEND email to actual email address ===
    email_struct =
      new()
      |> to({full_name, email})
      |> from({"VALUE8", "mutindasam39@gmail.com"})
      |> subject("Welcome to valu8 EAMS – Set Your Password")
      |> html_body(attachee_html_body(full_name, reset_url, organization, department, attachee))
      |> text_body(attachee_text_body(full_name, reset_url, organization, department, attachee))

    case Mailer.deliver(email_struct) do
      {:ok, _metadata} -> {:ok, :sent}
      {:error, reason} -> {:error, reason}
    end
  end

  # ——————————————————————————————————————————————————————
  # HTML BODY
  # ——————————————————————————————————————————————————————
  defp attachee_html_body(full_name, reset_url, organization, department, attachee) do
    start_date_html = if attachee.starts_on, do: "<p style='margin:5px 0;'><strong>Start Date:</strong> #{attachee.starts_on}</p>", else: ""
    end_date_html = if attachee.ends_on, do: "<p style='margin:5px 0;'><strong>End Date:</strong> #{attachee.ends_on}</p>", else: ""

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Welcome to valu8 EAMS</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #f9fafb;
        }
        .header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          padding: 40px 20px;
          text-align: center;
          border-radius: 10px 10px 0 0;
        }
        .header-logo {
          color: white;
          font-size: 28px;
          font-weight: bold;
          letter-spacing: 1px;
          margin: 0;
        }
        .header-subtitle {
          color: rgba(255,255,255,0.9);
          font-size: 14px;
          margin-top: 5px;
          margin-bottom: 0;
        }
        .content {
          background: #ffffff;
          padding: 30px;
          border: 1px solid #e5e7eb;
          border-radius: 0 0 10px 10px;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .info-section {
          background: #EFF6FF;
          padding: 20px;
          border-radius: 8px;
          margin: 20px 0;
          border-left: 4px solid #3B82F6;
        }
        .info-section h3 {
          margin-top: 0;
          color: #1E40AF;
          font-size: 18px;
        }
        .button {
          display: inline-block;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 14px 32px;
          text-decoration: none;
          border-radius: 8px;
          font-weight: 600;
          margin: 20px 0;
          text-align: center;
          border: none;
          font-size: 16px;
          box-shadow: 0 4px 6px rgba(102, 126, 234, 0.25);
        }
        .button:hover {
          background: linear-gradient(135deg, #5a6fd8 0%, #6a4190 100%);
          box-shadow: 0 6px 8px rgba(102, 126, 234, 0.35);
        }
        .warning {
          background: #FEF2F2;
          border-left: 4px solid #EF4444;
          padding: 15px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .warning strong {
          color: #DC2626;
        }
        .footer {
          text-align: center;
          color: #6B7280;
          font-size: 14px;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
        }
        .credentials-note {
          background: #FFFBEB;
          border: 1px solid #FCD34D;
          padding: 15px;
          border-radius: 6px;
          margin: 15px 0;
        }
        .credentials-note strong {
          color: #D97706;
        }
        ul {
          margin: 10px 0;
          padding-left: 20px;
        }
        li {
          margin-bottom: 5px;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1 class="header-logo">valu8 EAMS</h1>
        <p class="header-subtitle">Employee Attachment Management System</p>
      </div>

      <div class="content">
        <h2 style="color: #374151; margin-top: 0; text-align: center;">Welcome to valu8 EAMS!</h2>

        <p>Hi <strong>#{full_name}</strong>,</p>

        <p>Welcome to valu8 EAMS! Your attachee account has been successfully created.</p>

        <div class="credentials-note">
          <strong>🔒 Security First:</strong> For your protection, you must set your own password before accessing the system.
        </div>

        <div style="text-align: center;">
          <a href="#{reset_url}" class="button">Set My Password & Login</a>
        </div>

        <div class="info-section">
          <h3>📋 Your Program Details</h3>
          <p><strong>Organization:</strong> #{organization.name}</p>
          <p><strong>Department:</strong> #{department.name}</p>
          <p><strong>Program:</strong> #{attachee.position}</p>
          #{start_date_html}
          #{end_date_html}
        </div>

        <div class="warning">
          <strong>⚠️ Security Notice:</strong>
          <ul>
            <li>This link expires in <strong>24 hours</strong></li>
            <li>Do not share this link with anyone</li>
            <li>You will be logged in automatically after setting your password</li>
            <li>If the link expires, contact your supervisor for a new one</li>
          </ul>
        </div>

        <p>If you have any questions, contact your supervisor or our support team.</p>

        <p>Best regards,<br>
        <strong>The valu8 Team</strong></p>
      </div>

      <div class="footer">
        <p>This is an automated email. Please do not reply.</p>
        <p>&copy; #{Date.utc_today().year} valu8. All rights reserved.</p>
      </div>
    </body>
    </html>
    """
  end

  # ——————————————————————————————————————————————————————
  # TEXT BODY
  # ——————————————————————————————————————————————————————
  defp attachee_text_body(full_name, reset_url, organization, department, attachee) do
    start_date_text = if attachee.starts_on, do: "Start Date: #{attachee.starts_on}\n", else: ""
    end_date_text = if attachee.ends_on, do: "End Date: #{attachee.ends_on}\n", else: ""

    """
    Welcome to valu8 EAMS!

    Hi #{full_name},

    Your attachee account has been created. For security, you must set your own password before logging in.

    SET YOUR PASSWORD:
    #{reset_url}

    PROGRAM DETAILS
    ---------------
    Organization: #{organization.name}
    Department:   #{department.name}
    Program:      #{attachee.position}
    #{start_date_text}#{end_date_text}

    SECURITY
    --------
    - This link expires in 24 hours
    - Do not share it
    - You will be logged in automatically after setting your password
    - If the link expires, contact your supervisor for a new one

    Questions? Contact your supervisor.

    Best regards,
    The valu8 Team

    This is an automated email. Please do not reply.
    © #{Date.utc_today().year} valu8. All rights reserved.
    """
  end
end
