# priv/repo/seeds.exs
alias TrialApp.{Repo, Accounts}

# Create admin user directly with admin role
admin_attrs = %{
  email: "admin@trialapp.com",
  username: "admin",
  password: "admin123456"
}

# Create admin user using direct changeset
admin_changeset =
  %Accounts.User{}
  |> Ecto.Changeset.cast(admin_attrs, [:email, :username, :password])
  |> Ecto.Changeset.validate_required([:email, :username, :password])
  |> Ecto.Changeset.unique_constraint(:email)
  |> Ecto.Changeset.unique_constraint(:username)
  |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt(admin_attrs.password))
  |> Ecto.Changeset.put_change(:role, "admin")
  |> Ecto.Changeset.put_change(:status, "active")

case Repo.insert(admin_changeset) do
  {:ok, admin} ->
    IO.puts("Admin user created successfully!")
    IO.puts("Email: #{admin.email}")
    IO.puts("Username: #{admin.username}")
    IO.puts("Password: admin123456")
    IO.puts("Role: #{admin.role}")
    IO.puts("Status: #{admin.status}")

  {:error, changeset} ->
    IO.puts("Failed to create admin user:")
    IO.inspect(changeset.errors)
end

IO.puts("\nSeed data created successfully!")
IO.puts("Admin login: admin@trialapp.com / admin123456")
IO.puts("Access admin panel at: http://localhost:4000/admin/dashboard")
