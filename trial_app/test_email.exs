# Test script to send a sample welcome email
# Run with: mix run test_email.exs

# Create a test user struct (not saved to database)
test_user = %TrialApp.Accounts.User{
  email: "mutindasam39@gmail.com",
  first_name: "Sam",
  id: 999
}

test_password = "TestPassword123!"

# Send the email
IO.puts("Sending test welcome email to #{test_user.email}...")

case TrialApp.Accounts.UserNotifier.deliver_attachee_welcome_email(test_user, test_password) do
  {:ok, _email} ->
    IO.puts("✅ Email sent successfully!")
    IO.puts("Check your inbox at: #{test_user.email}")

  {:error, reason} ->
    IO.puts("❌ Failed to send email: #{inspect(reason)}")
end
