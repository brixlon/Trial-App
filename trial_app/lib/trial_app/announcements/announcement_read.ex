# lib/trial_app/announcements/announcement_read.ex

defmodule TrialApp.Announcements.AnnouncementRead do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcement_reads" do
    field :read_at, :utc_datetime

    belongs_to :announcement, TrialApp.Announcements.Announcement
    belongs_to :user, TrialApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(read, attrs) do
    read
    |> cast(attrs, [:announcement_id, :user_id, :read_at])
    |> validate_required([:announcement_id, :user_id, :read_at])
  end
end
