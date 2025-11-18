defmodule TrialApp.AttacheeNotifications do
  @moduledoc """
  Handles email notifications for attachees
  """

  import Swoosh.Email
  alias TrialApp.Mailer

  @doc """
  Sends a completion reminder to an attachee
  """
  def send_completion_reminder(attachee) do
    days_remaining = Date.diff(attachee.ends_on, Date.utc_today())

    new()
    |> to({attachee.user.username, attachee.user.email})
    |> from({"Attachee Management System", "noreply@yourcompany.com"})
    |> subject("Your Attachment is Ending Soon")
    |> html_body(completion_reminder_html(attachee, days_remaining))
    |> text_body(completion_reminder_text(attachee, days_remaining))
    |> Mailer.deliver()
  end

  @doc """
  Sends a status update notification
  """
  def send_status_update(attachee, old_status, new_status) do
    new()
    |> to({attachee.user.username, attachee.user.email})
    |> from({"Attachee Management System", "noreply@yourcompany.com"})
    |> subject("Attachment Status Updated")
    |> html_body(status_update_html(attachee, old_status, new_status))
    |> text_body(status_update_text(attachee, old_status, new_status))
    |> Mailer.deliver()
  end

  @doc """
  Sends a welcome email when attachee is created
  """
  def send_welcome_email(attachee) do
    new()
    |> to({attachee.user.username, attachee.user.email})
    |> from({"Attachee Management System", "noreply@yourcompany.com"})
    |> subject("Welcome to Your Attachment Program")
    |> html_body(welcome_email_html(attachee))
    |> text_body(welcome_email_text(attachee))
    |> Mailer.deliver()
  end

  @doc """
  Sends milestone completion notification
  """
  def send_milestone_notification(attachee, milestone_title) do
    new()
    |> to({attachee.user.username, attachee.user.email})
    |> from({"Attachee Management System", "noreply@yourcompany.com"})
    |> subject("Milestone Completed: #{milestone_title}")
    |> html_body(milestone_html(attachee, milestone_title))
    |> text_body(milestone_text(attachee, milestone_title))
    |> Mailer.deliver()
  end

  # HTML Email Templates

  defp completion_reminder_html(attachee, days_remaining) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9fafb; padding: 30px; border-radius: 0 0 10px 10px; }
        .alert-box { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .info-box { background: white; padding: 20px; border-radius: 5px; margin: 20px 0; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .info-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e5e7eb; }
        .info-label { font-weight: bold; color: #6b7280; }
        .info-value { color: #1f2937; }
        .button { display: inline-block; background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
        .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Attachment Completion Reminder</h1>
        </div>
        <div class="content">
          <p>Hello #{attachee.user.username},</p>

          <div class="alert-box">
            <strong>⏰ Your attachment is ending soon!</strong>
            <p style="margin: 10px 0 0 0;">Your attachment at #{attachee.organization.name} will be completed in <strong>#{days_remaining} days</strong>.</p>
          </div>

          <div class="info-box">
            <h3 style="margin-top: 0;">Attachment Details</h3>
            <div class="info-row">
              <span class="info-label">Organization:</span>
              <span class="info-value">#{attachee.organization.name}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Department:</span>
              <span class="info-value">#{attachee.department.name}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Start Date:</span>
              <span class="info-value">#{Calendar.strftime(attachee.starts_on, "%B %d, %Y")}</span>
            </div>
            <div class="info-row" style="border: none;">
              <span class="info-label">End Date:</span>
              <span class="info-value">#{Calendar.strftime(attachee.ends_on, "%B %d, %Y")}</span>
            </div>
          </div>

          <h3>Action Items Before Completion:</h3>
          <ul>
            <li>Complete any pending tasks and projects</li>
            <li>Submit your final evaluation form</li>
            <li>Return any company equipment or materials</li>
            <li>Collect your completion certificate</li>
            <li>Update your contact information for follow-up</li>
          </ul>

          <p>If you have any questions or need assistance, please contact your supervisor or HR department.</p>

          <div class="footer">
            <p>This is an automated notification from the Attachee Management System</p>
            <p>&copy; #{Date.utc_today().year} Your Company. All rights reserved.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp status_update_html(attachee, old_status, new_status) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9fafb; padding: 30px; border-radius: 0 0 10px 10px; }
        .status-box { background: white; padding: 20px; border-radius: 5px; margin: 20px 0; text-align: center; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .status-badge { display: inline-block; padding: 8px 16px; border-radius: 20px; font-weight: bold; margin: 0 10px; }
        .status-active { background: #d1fae5; color: #065f46; }
        .status-inactive { background: #fef3c7; color: #92400e; }
        .status-completed { background: #dbeafe; color: #1e40af; }
        .arrow { font-size: 24px; color: #6b7280; }
        .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Status Update Notification</h1>
        </div>
        <div class="content">
          <p>Hello #{attachee.user.username},</p>

          <p>Your attachment status has been updated.</p>

          <div class="status-box">
            <span class="status-badge status-#{old_status}">#{String.upcase(old_status)}</span>
            <span class="arrow">→</span>
            <span class="status-badge status-#{new_status}">#{String.upcase(new_status)}</span>
          </div>

          <p><strong>Organization:</strong> #{attachee.organization.name}</p>
          <p><strong>Department:</strong> #{attachee.department.name}</p>

          #{status_message(new_status)}

          <div class="footer">
            <p>This is an automated notification from the Attachee Management System</p>
            <p>&copy; #{Date.utc_today().year} Your Company. All rights reserved.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp welcome_email_html(attachee) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9fafb; padding: 30px; border-radius: 0 0 10px 10px; }
        .welcome-box { background: white; padding: 25px; border-radius: 5px; margin: 20px 0; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .milestone-list { background: #ede9fe; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .milestone-item { padding: 10px 0; border-bottom: 1px solid #c4b5fd; }
        .milestone-item:last-child { border: none; }
        .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎉 Welcome to Your Attachment!</h1>
        </div>
        <div class="content">
          <p>Hello #{attachee.user.username},</p>

          <p>Congratulations! You have been successfully enrolled in the attachment program.</p>

          <div class="welcome-box">
            <h3 style="margin-top: 0;">Your Attachment Details</h3>
            <p><strong>Organization:</strong> #{attachee.organization.name}</p>
            <p><strong>Department:</strong> #{attachee.department.name}</p>
            <p><strong>Start Date:</strong> #{Calendar.strftime(attachee.starts_on, "%B %d, %Y")}</p>
            <p><strong>End Date:</strong> #{Calendar.strftime(attachee.ends_on, "%B %d, %Y")}</p>
            <p><strong>Duration:</strong> 3 months (90 days)</p>
          </div>

          <h3>What to Expect:</h3>
          <div class="milestone-list">
            <div class="milestone-item">📋 <strong>Week 1:</strong> Orientation and department introduction</div>
            <div class="milestone-item">💼 <strong>Week 2-3:</strong> First project assignment</div>
            <div class="milestone-item">📊 <strong>Week 6:</strong> Mid-term evaluation</div>
            <div class="milestone-item">🎯 <strong>Week 11:</strong> Final project submission</div>
            <div class="milestone-item">🏆 <strong>Week 12:</strong> Final evaluation and completion</div>
          </div>

          <h3>Getting Started:</h3>
          <ul>
            <li>Review your attachment schedule and objectives</li>
            <li>Connect with your supervisor on day one</li>
            <li>Complete all orientation requirements</li>
            <li>Set up your workspace and necessary accounts</li>
          </ul>

          <p>We wish you all the best in your attachment journey!</p>

          <div class="footer">
            <p>This is an automated notification from the Attachee Management System</p>
            <p>&copy; #{Date.utc_today().year} Your Company. All rights reserved.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp milestone_html(attachee, milestone_title) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9fafb; padding: 30px; border-radius: 0 0 10px 10px; }
        .success-box { background: #d1fae5; border-left: 4px solid #10b981; padding: 20px; margin: 20px 0; border-radius: 5px; }
        .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>✅ Milestone Completed!</h1>
        </div>
        <div class="content">
          <p>Hello #{attachee.user.username},</p>

          <div class="success-box">
            <h3 style="margin-top: 0;">Congratulations!</h3>
            <p>You have successfully completed: <strong>#{milestone_title}</strong></p>
          </div>

          <p>Keep up the great work! Continue progressing through your attachment milestones.</p>

          <div class="footer">
            <p>This is an automated notification from the Attachee Management System</p>
            <p>&copy; #{Date.utc_today().year} Your Company. All rights reserved.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  # Text Email Templates (for email clients that don't support HTML)

  defp completion_reminder_text(attachee, days_remaining) do
    """
    Hello #{attachee.user.username},

    Your attachment at #{attachee.organization.name} will be completed in #{days_remaining} days.

    Attachment Details:
    - Organization: #{attachee.organization.name}
    - Department: #{attachee.department.name}
    - Start Date: #{attachee.starts_on}
    - End Date: #{attachee.ends_on}

    Action Items Before Completion:
    - Complete any pending tasks and projects
    - Submit your final evaluation form
    - Return any company equipment or materials
    - Collect your completion certificate

    If you have any questions, please contact your supervisor or HR department.

    ---
    Attachee Management System
    """
  end

  defp status_update_text(attachee, old_status, new_status) do
    """
    Hello #{attachee.user.username},

    Your attachment status has been updated from #{String.upcase(old_status)} to #{String.upcase(new_status)}.

    Organization: #{attachee.organization.name}
    Department: #{attachee.department.name}

    #{status_message_text(new_status)}

    ---
    Attachee Management System
    """
  end

  defp welcome_email_text(attachee) do
    """
    Hello #{attachee.user.username},

    Welcome to your attachment program!

    Your Attachment Details:
    - Organization: #{attachee.organization.name}
    - Department: #{attachee.department.name}
    - Start Date: #{attachee.starts_on}
    - End Date: #{attachee.ends_on}
    - Duration: 3 months (90 days)

    We wish you all the best in your attachment journey!

    ---
    Attachee Management System
    """
  end

  defp milestone_text(attachee, milestone_title) do
    """
    Hello #{attachee.user.username},

    Congratulations! You have successfully completed: #{milestone_title}

    Keep up the great work!

    ---
    Attachee Management System
    """
  end

  # Helper functions

  defp status_message("active") do
    "<p>Your attachment is now <strong>active</strong>. Make the most of your time and engage fully with your team and projects.</p>"
  end
  defp status_message("inactive") do
    "<p>Your attachment is currently <strong>inactive</strong>. Please contact your supervisor if you have any questions.</p>"
  end
  defp status_message("completed") do
    "<p>Congratulations! Your attachment has been <strong>completed</strong>. Thank you for your participation and we hope you had a valuable learning experience.</p>"
  end
  defp status_message(_), do: ""

  defp status_message_text("active"), do: "Your attachment is now active."
  defp status_message_text("inactive"), do: "Your attachment is currently inactive."
  defp status_message_text("completed"), do: "Congratulations! Your attachment has been completed."
  defp status_message_text(_), do: ""
end
