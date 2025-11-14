# priv/repo/migrations/XXXXXXXXXXXXXX_create_announcements.exs

defmodule TrialApp.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  def change do
    create table(:announcements) do
      add :title, :string, null: false
      add :content, :text, null: false
      add :category, :string, null: false
      add :priority, :string, default: "normal", null: false
      add :pinned, :boolean, default: false
      add :publish_date, :utc_datetime, null: false
      add :expiry_date, :utc_datetime
      add :creator_id, references(:users, on_delete: :nilify_all)
      add :creator_role, :string, null: false # "admin" or "supervisor"

      timestamps(type: :utc_datetime)
    end

    create index(:announcements, [:creator_id])
    create index(:announcements, [:publish_date])
    create index(:announcements, [:pinned])

    # Junction table for announcement targets (who can see it)
    create table(:announcement_targets) do
      add :announcement_id, references(:announcements, on_delete: :delete_all), null: false
      add :target_type, :string, null: false # "all_attachees", "specific_attachee", "all_supervisors", "specific_supervisor", "everyone"
      add :target_id, references(:users, on_delete: :delete_all) # null if target_type is "all_*" or "everyone"

      timestamps(type: :utc_datetime)
    end

    create index(:announcement_targets, [:announcement_id])
    create index(:announcement_targets, [:target_id])
    create unique_index(:announcement_targets, [:announcement_id, :target_type, :target_id], name: :unique_announcement_target)

    # Table to track read status
    create table(:announcement_reads) do
      add :announcement_id, references(:announcements, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :read_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:announcement_reads, [:user_id])
    create unique_index(:announcement_reads, [:announcement_id, :user_id])

    
    create table(:announcement_links) do
      add :announcement_id, references(:announcements, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :title, :string

      timestamps(type: :utc_datetime)
    end

    create index(:announcement_links, [:announcement_id])
  end
end
