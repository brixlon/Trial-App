defmodule TrialApp.Repo.Migrations.MigrateToRbac do
  use Ecto.Migration

  def up do
    # ========== PHASE 1: CREATE NEW TABLES ==========

    # Create roles table
    create table(:roles) do
      add :name, :string, null: false
      add :description, :text
      add :is_system_role, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:roles, [:name])

    # Create permissions table
    create table(:permissions) do
      add :slug, :string, null: false
      add :description, :text
      # e.g., "users", "organizations", "reports"
      add :category, :string

      timestamps()
    end

    create unique_index(:permissions, [:slug])

    # Create role_permissions join table
    create table(:role_permissions, primary_key: false) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:role_permissions, [:role_id])
    create index(:role_permissions, [:permission_id])
    create unique_index(:role_permissions, [:role_id, :permission_id])

    # ========== PHASE 2: ADD NEW COLUMN TO USERS ==========

    alter table(:users) do
      # NULLABLE for now
      add :role_id, references(:roles, on_delete: :restrict), null: true
    end

    create index(:users, [:role_id])

    # ========== PHASE 3: DATA MIGRATION ==========

    # Ensure tables are created before data migration
    flush()

    # Insert standard roles based on existing data
    execute """
    INSERT INTO roles (name, description, is_system_role, inserted_at, updated_at)
    VALUES
      ('admin', 'System Administrator - Full Access', true, NOW(), NOW()),
      ('supervisor', 'Supervisor - Manage attachees and evaluations', true, NOW(), NOW()),
      ('attachee', 'Attachee/Student - Limited access', true, NOW(), NOW()),
      ('manager', 'Manager - Department management', true, NOW(), NOW()),
      ('employee', 'Employee - Basic access', true, NOW(), NOW()),
      ('user', 'Default User - Minimal access', true, NOW(), NOW())
    ON CONFLICT (name) DO NOTHING
    """

    # Create standard permissions
    execute """
    INSERT INTO permissions (slug, description, category, inserted_at, updated_at)
    VALUES
      -- User Management
      ('manage_users', 'Create, edit, and delete users', 'users', NOW(), NOW()),
      ('view_users', 'View user list and details', 'users', NOW(), NOW()),
      ('approve_users', 'Approve pending user registrations', 'users', NOW(), NOW()),

      -- Organization Management
      ('manage_organizations', 'Create, edit, and delete organizations', 'organizations', NOW(), NOW()),
      ('view_organizations', 'View organization structure', 'organizations', NOW(), NOW()),
      ('manage_departments', 'Create, edit, and delete departments', 'organizations', NOW(), NOW()),
      ('manage_teams', 'Create, edit, and delete teams', 'organizations', NOW(), NOW()),

      -- Attachee Management
      ('manage_attachees', 'Manage attachee assignments and tasks', 'attachees', NOW(), NOW()),
      ('view_attachees', 'View attachee information', 'attachees', NOW(), NOW()),
      ('evaluate_attachees', 'Create and submit evaluations', 'attachees', NOW(), NOW()),

      -- Reports & Analytics
      ('view_reports', 'View system reports', 'reports', NOW(), NOW()),
      ('generate_reports', 'Generate and download reports', 'reports', NOW(), NOW()),

      -- Dashboard Access
      ('access_admin_dashboard', 'Access administrator dashboard', 'dashboard', NOW(), NOW()),
      ('access_supervisor_dashboard', 'Access supervisor dashboard', 'dashboard', NOW(), NOW()),
      ('access_attachee_dashboard', 'Access attachee dashboard', 'dashboard', NOW(), NOW()),

      -- Announcements
      ('manage_announcements', 'Create and manage announcements', 'announcements', NOW(), NOW()),
      ('view_announcements', 'View announcements', 'announcements', NOW(), NOW())
    ON CONFLICT (slug) DO NOTHING
    """

    # Map permissions to roles
    execute """
    INSERT INTO role_permissions (role_id, permission_id, inserted_at, updated_at)
    SELECT r.id, p.id, NOW(), NOW()
    FROM roles r
    CROSS JOIN permissions p
    WHERE
      -- Admin gets ALL permissions
      (r.name = 'admin') OR

      -- Supervisor permissions
      (r.name = 'supervisor' AND p.slug IN (
        'view_users', 'approve_users',
        'view_organizations', 'view_attachees', 'manage_attachees', 'evaluate_attachees',
        'view_reports', 'generate_reports',
        'access_supervisor_dashboard', 'view_announcements'
      )) OR

      -- Attachee permissions
      (r.name = 'attachee' AND p.slug IN (
        'view_organizations', 'access_attachee_dashboard', 'view_announcements'
      )) OR

      -- Manager permissions
      (r.name = 'manager' AND p.slug IN (
        'view_users', 'view_organizations', 'manage_departments', 'manage_teams',
        'view_reports', 'access_admin_dashboard', 'view_announcements'
      )) OR

      -- Employee permissions
      (r.name = 'employee' AND p.slug IN (
        'view_organizations', 'view_announcements'
      )) OR

      -- User (default) permissions
      (r.name = 'user' AND p.slug IN (
        'view_announcements'
      ))
    ON CONFLICT (role_id, permission_id) DO NOTHING
    """

    # Migrate existing users' roles to role_id
    # This handles the primary 'role' field
    execute """
    UPDATE users u
    SET role_id = r.id
    FROM roles r
    WHERE u.role = r.name
    AND u.role_id IS NULL
    """

    # For users with NULL or invalid roles, assign 'user' role
    execute """
    UPDATE users u
    SET role_id = r.id
    FROM roles r
    WHERE r.name = 'user'
    AND u.role_id IS NULL
    """

    # Verify all users have a role_id
    execute """
    DO $$
    DECLARE
      unassigned_count INTEGER;
    BEGIN
      SELECT COUNT(*) INTO unassigned_count FROM users WHERE role_id IS NULL;
      IF unassigned_count > 0 THEN
        RAISE EXCEPTION 'Data migration failed: % users without role_id', unassigned_count;
      END IF;
    END $$;
    """

    # ========== PHASE 4: CLEANUP OLD COLUMNS ==========

    # Now that all users have role_id, make it NOT NULL
    alter table(:users) do
      modify :role_id, :bigint, null: false
    end

    # Drop old role column
    alter table(:users) do
      remove :role
    end

    # Note: We keep 'roles' array and 'active_role' for now to maintain backward compatibility
    # These can be removed in a future migration after code is fully refactored
  end

  def down do
    # Restore old role column
    alter table(:users) do
      add :role, :string, default: "user"
    end

    # Restore role data from role_id
    execute """
    UPDATE users u
    SET role = r.name
    FROM roles r
    WHERE u.role_id = r.id
    """

    # Remove role_id
    alter table(:users) do
      remove :role_id
    end

    # Drop RBAC tables
    drop table(:role_permissions)
    drop table(:permissions)
    drop table(:roles)
  end
end
