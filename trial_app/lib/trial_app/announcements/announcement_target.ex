# lib/trial_app/announcements/announcement_target.ex

defmodule TrialApp.Announcements.AnnouncementTarget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "announcement_targets" do
    field :target_type, :string

    belongs_to :announcement, TrialApp.Announcements.Announcement
    belongs_to :target, TrialApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @target_types ["all_attachees", "specific_attachee", "all_supervisors", "specific_supervisor", "everyone"]

  def changeset(target, attrs) do
    target
    |> cast(attrs, [:announcement_id, :target_type, :target_id])
    |> validate_required([:announcement_id, :target_type])
    |> validate_inclusion(:target_type, @target_types)
  end

  def target_types, do: @target_types
end
