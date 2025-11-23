# priv/repo/seeds.exs
alias TrialApp.{Repo, Accounts}
alias TrialApp.Accounts.{User, Role}

# Get admin role (should exist from migration)
admin_role = Repo.get_by(Role, name: "admin")

unless admin_role do
  IO.puts("❌ ERROR: Admin role not found!")
  IO.puts("   Please run migrations first: mix ecto.migrate")
  System.halt(1)
end

# Create admin user
admin_attrs = %{
  email: "developer@trialapp.com",
  username: "developer",
  password: "@@@mwendia19",
  role_id: admin_role.id,
  status: "active"
}

admin_changeset =
  %User{}
  |> Ecto.Changeset.cast(admin_attrs, [:email, :username, :password, :role_id, :status])
  |> Ecto.Changeset.validate_required([:email, :username, :password, :role_id])
  |> Ecto.Changeset.unique_constraint(:email)
  |> Ecto.Changeset.unique_constraint(:username)
  |> Ecto.Changeset.put_change(:hashed_password, Bcrypt.hash_pwd_salt(admin_attrs.password))

case Repo.insert(admin_changeset, on_conflict: :nothing) do
  {:ok, admin} ->
    IO.puts("\n✅ Admin user created successfully!")
    IO.puts("   Email: #{admin.email}")
    IO.puts("   Username: #{admin.username}")
    IO.puts("   Role: admin (ID: #{admin.role_id})")
    IO.puts("   Status: #{admin.status}")

  {:error, changeset} ->
    if Repo.get_by(User, email: admin_attrs.email) do
      IO.puts("\n✅ Admin user already exists")
      IO.puts("   Email: #{admin_attrs.email}")
    else
      IO.puts("\n❌ Failed to create admin user:")
      IO.inspect(changeset.errors)
    end
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✅ Seed data completed!")
IO.puts(String.duplicate("=", 60))
IO.puts("\n📝 Login Credentials:")
IO.puts("   Email: developer@trialapp.com")
IO.puts("   Password: @@@mwendia19")
IO.puts("\n🔐 RBAC System:")
IO.puts("   Roles: #{Enum.count(Repo.all(Role))} roles configured")
IO.puts("   Permissions: #{Enum.count(Repo.all(Accounts.Permission))} permissions configured")
IO.puts("\n🌐 Access the application at: http://localhost:4000")
IO.puts(String.duplicate("=", 60) <> "\n")
