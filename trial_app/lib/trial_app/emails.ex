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
  """
  def attachee_credentials_email(attachee, _plain_password) do
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

    # === 4. Build email ===
    new()
    |> to({full_name, email})
    |> from({"Trial App System", "noreply@trialapp.com"})
    |> subject("Welcome to Trial App – Set Your Password")
    |> html_body(attachee_html_body(full_name, reset_url, organization, department, attachee))
    |> text_body(attachee_text_body(full_name, reset_url, organization, department, attachee))
  end

  # ——————————————————————————————————————————————————————
  # HTML BODY (Your beautiful design — unchanged except button & password removal)
  # ——————————————————————————————————————————————————————
  defp attachee_html_body(full_name, reset_url, organization, department, attachee) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background: linear-gradient(135deg, #6C63FF 0%, #5A52E8 100%);
          color: white;
          padding: 30px;
          border-radius: 10px 10px 0 0;
          text-align: center;
        }
        .header h1 {
          margin: 0;
          font-size: 28px;
        }
        .content {
          background: #ffffff;
          padding: 30px;
          border: 1px solid #e5e7eb;
          border-top: none;
        }
        .info-section {
          background: #EFF6FF;
          padding: 20px;
          border-radius: 8px;
          margin: 20px 0;
        }
        .info-section h3 {
          margin-top: 0;
          color: #3B82F6;
        }
        .button {
          display: inline-block;
          background: linear-gradient(135deg, #6C63FF 0%, #5A52E8 100%);
          color: white;
          padding: 14px 32px;
          text-decoration: none;
          border-radius: 8px;
          font-weight: 600;
          margin: 20px 0;
          text-align: center;
        }
        .warning {
          background: #FEF2F2;
          border-left: 4px solid #EF4444;
          padding: 15px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .footer {
          text-align: center;
          color: #6B7280;
          font-size: 14px;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Welcome to Trial App!</h1>
        <p style="margin: 10px 0 0 0; opacity: 0.9;">Your Attachee Account is Ready</p>
      </div>

      <div class="content">
        <p>Hi <strong>#{full_name}</strong>,</p>

        <p>Welcome to Trial App! Your attachee account has been successfully created.</p>

        <p><strong>For security, you must set your own password before logging in.</strong></p>

        <div style="text-align: center;">
          <a href="#{reset_url}" class="button">
            Set My Password
          </a>
        </div>

        <div class="info-section">
          <h3>Your Program Details</h3>
          <p style="margin: 5px 0;"><strong>Organization:</strong> #{organization.name}</p>
          <p style="margin: 5px 0;"><strong>Department:</strong> #{department.name}</p>
          <p style="margin: 5px 0;"><strong>Program:</strong> #{attachee.position}</p>
          #{if attachee.starts_on, do: "<p style=\"margin: 5px 0;\"><strong>Start Date:</strong> #{attachee.starts_on}</p>", else: ""}
          #{if attachee.ends_on, do: "<p style=\"margin: 5px 0;\"><strong>End Date:</strong> #{attachee.ends_on}</p>", else: ""}
        </div>

        <div class="warning">
          <strong>Security Notice:</strong>
          <ul style="margin: 10px 0;">
            <li>This link expires in <strong>24 hours</strong></li>
            <li>Do not share this link with anyone</li>
            <li>You will be logged in automatically after setting your password</li>
          </ul>
        </div>

        <p>If you have any questions, contact your supervisor or our support team.</p>

        <p>Best regards,<br>
        <strong>Trial App Team</strong></p>
      </div>

      <div class="footer">
        <p>This is an automated email. Please do not reply.</p>
        <p>&copy; #{Date.utc_today().year} Trial App. All rights reserved.</p>
      </div>
    </body>
    </html>
    """
  end

  # ——————————————————————————————————————————————————————
  # TEXT BODY (Plain text version)
  # ——————————————————————————————————————————————————————
  defp attachee_text_body(full_name, reset_url, organization, department, attachee) do
    """
    Welcome to Trial App!

    Hi #{full_name},

    Your attachee account has been created. For security, you must set your own password before logging in.

    SET YOUR PASSWORD:
    #{reset_url}

    PROGRAM DETAILS
    ---------------
    Organization: #{organization.name}
    Department:   #{department.name}
    Program:      #{attachee.position}
    #{if attachee.starts_on, do: "Start Date: #{attachee.starts_on}\n", else: ""}
    #{if attachee.ends_on, do: "End Date: #{attachee.ends_on}\n", else: ""}

    SECURITY
    --------
    - This link expires in 24 hours
    - Do not share it
    - You will be logged in automatically after setting your password

    Questions? Contact your supervisor.

    Trial App Team
    """
  end
end
