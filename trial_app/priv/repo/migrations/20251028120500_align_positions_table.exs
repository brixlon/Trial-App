defmodule TrialApp.Repo.Migrations.AlignPositionsTable do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'positions' AND column_name = 'name'
      ) THEN
        ALTER TABLE positions ADD COLUMN name text;
        UPDATE positions SET name = 'Unknown' WHERE name IS NULL;
        ALTER TABLE positions ALTER COLUMN name SET NOT NULL;
      END IF;
    END$$;
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'positions' AND column_name = 'description'
      ) THEN
        ALTER TABLE positions ADD COLUMN description text;
      END IF;
    END$$;
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'positions' AND column_name = 'is_active'
      ) THEN
        ALTER TABLE positions ADD COLUMN is_active boolean NOT NULL DEFAULT true;
      END IF;
    END$$;
    """)

    execute("CREATE UNIQUE INDEX IF NOT EXISTS positions_name_index ON positions (name);")
  end

  def down do
    execute("DROP INDEX IF EXISTS positions_name_index;")
    # We won't drop columns in down to avoid data loss; adjust if needed
  end
end
