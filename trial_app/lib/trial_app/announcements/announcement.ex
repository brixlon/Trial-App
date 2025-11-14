# lib/trial_app/announcements/announcement.ex

defmodule TrialApp.Announcements.Announcement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcements" do
    field :title, :string
    field :content, :string
    field :category, :string
    field :priority, :string, default: "normal"
    field :pinned, :boolean, default: false
    field :publish_date, :utc_datetime
    field :expiry_date, :utc_datetime
    field :creator_role, :string

    belongs_to :creator, TrialApp.Accounts.User
    has_many :targets, TrialApp.Announcements.AnnouncementTarget
    has_many :reads, TrialApp.Announcements.AnnouncementRead
    has_many :links, TrialApp.Announcements.AnnouncementLink

    timestamps(type: :utc_datetime)
  end

  @categories ["general_update", "training", "policy_change", "event", "deadline", "recognition", "learning_materials"]
  @priorities ["normal", "important", "urgent"]

  def changeset(announcement, attrs) do
    announcement
    |> cast(attrs, [:title, :content, :category, :priority, :pinned,
                    :publish_date, :expiry_date, :creator_id, :creator_role])
    |> validate_required([:title, :content, :category, :priority, :creator_role, :publish_date])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:priority, @priorities)
    |> validate_inclusion(:creator_role, ["admin", "supervisor"])
  end

  def categories, do: @categories
  def priorities, do: @priorities
end
