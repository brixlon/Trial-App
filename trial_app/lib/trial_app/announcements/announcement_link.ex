# lib/trial_app/announcements/announcement_link.ex

defmodule TrialApp.Announcements.AnnouncementLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcement_links" do
    field :url, :string
    field :title, :string

    belongs_to :announcement, TrialApp.Announcements.Announcement

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:announcement_id, :url, :title])
    |> validate_required([:announcement_id, :url])
    |> validate_format(:url, ~r/^https?:\/\//)
  end
end
