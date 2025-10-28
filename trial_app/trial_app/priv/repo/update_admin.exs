# priv/repo/update_admin.exs
alias TrialApp.{Repo, Accounts}

# Get the existing admin user
admin_user = Accounts.get_user_by_email("admin@trialapp.com")

if admin_user do
  # Update the user to be an admin
  changeset =
    admin_user
    |> Ecto.Changeset.change(%{role: "admin", status: "active"})

  case Repo.update(changeset) do
    {:ok, user} ->
      IO.puts("Admin user updated successfully!")
      IO.puts("Email: #{user.email}")
      IO.puts("Username: #{user.username}")
      IO.puts("Role: #{user.role}")
      IO.puts("Status: #{user.status}")
      IO.puts("\nYou can now login as admin at: http://localhost:4000/admin/dashboard")

    {:error, changeset} ->
      IO.puts("Failed to update admin user:")
      IO.inspect(changeset.errors)
  end
else
  IO.puts("Admin user not found!")
end
