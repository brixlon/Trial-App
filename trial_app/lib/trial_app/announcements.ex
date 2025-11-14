# lib/trial_app/announcements.ex

defmodule TrialApp.Announcements do
  @moduledoc """
  The Announcements context.
  """

  import Ecto.Query, warn: false
  alias TrialApp.Repo
  alias TrialApp.Announcements.{Announcement, AnnouncementTarget, AnnouncementRead, AnnouncementLink}
  alias TrialApp.Eams
  alias TrialApp.Accounts.User

  ## Announcement CRUD

  def list_announcements_for_user(user_id, user_role) do
    now = DateTime.utc_now()

    # Build the base query
    base_query =
      Announcement
      |> where([a], a.publish_date <= ^now)
      |> where([a], is_nil(a.expiry_date) or a.expiry_date > ^now)
      |> join(:inner, [a], t in assoc(a, :targets))

    # Build role-specific conditions
    final_query = case user_role do
      "attachee" ->
        case Eams.get_attachee_by_user(user_id) do
          nil ->
            # No attachee profile - only "everyone" announcements
            base_query
            |> where([a, t], t.target_type == "everyone")

          attachee ->
            # Has attachee profile - get their projects
            projects = Eams.list_projects_for_attachee(attachee.id)
            project_ids = Enum.map(projects, & to_string(&1.id))
            attachee_id_str = to_string(attachee.id)

            # Build conditions for attachees
            if project_ids == [] do
              # No projects assigned
              base_query
              |> where([a, t],
                t.target_type == "everyone" or
                t.target_type == "all_attachees" or
                (t.target_type == "specific_attachee" and t.target_id == ^attachee_id_str)
              )
            else
              # Has projects assigned
              base_query
              |> where([a, t],
                t.target_type == "everyone" or
                t.target_type == "all_attachees" or
                (t.target_type == "specific_attachee" and t.target_id == ^attachee_id_str) or
                (t.target_type == "project" and t.target_id in ^project_ids)
              )
            end
        end

      "supervisor" ->
        user_id_str = to_string(user_id)

        base_query
        |> where([a, t],
          t.target_type == "everyone" or
          t.target_type == "all_supervisors" or
          (t.target_type == "specific_supervisor" and t.target_id == ^user_id_str)
        )

      "admin" ->
        user_id_str = to_string(user_id)

        base_query
        |> where([a, t],
          t.target_type == "everyone" or
          t.target_type == "all_supervisors" or
          t.target_type == "all_attachees" or
          (t.target_type == "specific_supervisor" and t.target_id == ^user_id_str)
        )

      _ ->
        # Other roles - only "everyone" announcements
        base_query
        |> where([a, t], t.target_type == "everyone")
    end

    final_query
    |> distinct(true)
    |> order_by([a], [desc: a.pinned, desc: a.priority, desc: a.publish_date])
    |> preload([:creator, :targets, :links])
    |> Repo.all()
  end

  def list_all_announcements do
    Announcement
    |> order_by([a], [desc: a.publish_date])
    |> preload([:creator, :targets, :links])
    |> Repo.all()
  end

  def get_unread_count(user_id, user_role) do
    now = DateTime.utc_now()

    # Subquery for read announcements
    read_subquery =
      from ar in AnnouncementRead,
      where: ar.user_id == ^user_id,
      select: ar.announcement_id

    # Base query
    base_query =
      Announcement
      |> where([a], a.publish_date <= ^now)
      |> where([a], is_nil(a.expiry_date) or a.expiry_date > ^now)
      |> where([a], a.id not in subquery(read_subquery))
      |> join(:inner, [a], t in assoc(a, :targets))

    # Build role-specific conditions
    final_query = case user_role do
      "attachee" ->
        case Eams.get_attachee_by_user(user_id) do
          nil ->
            # No attachee profile - only "everyone" announcements
            base_query
            |> where([a, t], t.target_type == "everyone")

          attachee ->
            # Has attachee profile - get their projects
            projects = Eams.list_projects_for_attachee(attachee.id)
            project_ids = Enum.map(projects, & to_string(&1.id))
            attachee_id_str = to_string(attachee.id)

            # Build conditions for attachees
            if project_ids == [] do
              # No projects assigned
              base_query
              |> where([a, t],
                t.target_type == "everyone" or
                t.target_type == "all_attachees" or
                (t.target_type == "specific_attachee" and t.target_id == ^attachee_id_str)
              )
            else
              # Has projects assigned
              base_query
              |> where([a, t],
                t.target_type == "everyone" or
                t.target_type == "all_attachees" or
                (t.target_type == "specific_attachee" and t.target_id == ^attachee_id_str) or
                (t.target_type == "project" and t.target_id in ^project_ids)
              )
            end
        end

      "supervisor" ->
        user_id_str = to_string(user_id)

        base_query
        |> where([a, t],
          t.target_type == "everyone" or
          t.target_type == "all_supervisors" or
          (t.target_type == "specific_supervisor" and t.target_id == ^user_id_str)
        )

      "admin" ->
        user_id_str = to_string(user_id)

        base_query
        |> where([a, t],
          t.target_type == "everyone" or
          t.target_type == "all_supervisors" or
          t.target_type == "all_attachees" or
          (t.target_type == "specific_supervisor" and t.target_id == ^user_id_str)
        )

      _ ->
        # Other roles - only "everyone" announcements
        base_query
        |> where([a, t], t.target_type == "everyone")
    end

    final_query
    |> distinct(true)
    |> Repo.aggregate(:count)
  end

  def get_announcement!(id) do
    Announcement
    |> preload([:creator, :targets, :links])
    |> Repo.get!(id)
  end

  def create_announcement(attrs \\ %{}, targets \\ [], links \\ []) do
    Repo.transaction(fn ->
      with {:ok, announcement} <-
             %Announcement{}
             |> Announcement.changeset(attrs)
             |> Repo.insert(),
           {:ok, _targets} <- create_announcement_targets(announcement.id, targets),
           {:ok, _links} <- create_announcement_links(announcement.id, links) do
        announcement |> Repo.preload([:creator, :targets, :links])
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_announcement(%Announcement{} = announcement, attrs, targets \\ nil, links \\ nil) do
    Repo.transaction(fn ->
      with {:ok, announcement} <-
             announcement
             |> Announcement.changeset(attrs)
             |> Repo.update() do

        # Update targets if provided
        if targets do
          delete_announcement_targets(announcement.id)
          create_announcement_targets(announcement.id, targets)
        end

        # Update links if provided
        if links do
          delete_announcement_links(announcement.id)
          create_announcement_links(announcement.id, links)
        end

        announcement |> Repo.preload([:creator, :targets, :links], force: true)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def delete_announcement(%Announcement{} = announcement) do
    Repo.delete(announcement)
  end

  ## Announcement Targets

  defp create_announcement_targets(announcement_id, targets) do
    targets_to_insert =
      Enum.map(targets, fn target ->
        %{
          announcement_id: announcement_id,
          target_type: target.target_type,
          target_id: target[:target_id],
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      end)

    case targets_to_insert do
      [] -> {:ok, []}
      _ ->
        Repo.insert_all(AnnouncementTarget, targets_to_insert)
        {:ok, targets_to_insert}
    end
  end

  defp delete_announcement_targets(announcement_id) do
    from(t in AnnouncementTarget, where: t.announcement_id == ^announcement_id)
    |> Repo.delete_all()
  end

  ## Announcement Links

  defp create_announcement_links(announcement_id, links) do
    links_to_insert =
      Enum.map(links, fn link ->
        %{
          announcement_id: announcement_id,
          url: link.url,
          title: link[:title],
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      end)

    case links_to_insert do
      [] -> {:ok, []}
      _ ->
        Repo.insert_all(AnnouncementLink, links_to_insert)
        {:ok, links_to_insert}
    end
  end

  defp delete_announcement_links(announcement_id) do
    from(l in AnnouncementLink, where: l.announcement_id == ^announcement_id)
    |> Repo.delete_all()
  end

  ## Mark as Read

  def mark_as_read(announcement_id, user_id) do
    %AnnouncementRead{}
    |> AnnouncementRead.changeset(%{
      announcement_id: announcement_id,
      user_id: user_id,
      read_at: DateTime.utc_now()
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def is_read?(announcement_id, user_id) do
    AnnouncementRead
    |> where([ar], ar.announcement_id == ^announcement_id and ar.user_id == ^user_id)
    |> Repo.exists?()
  end

  ## Helper functions - Get target options based on role

  def get_target_options_for_role("admin") do
    supervisors = get_all_supervisors()
    attachees = get_all_attachees()
    projects = get_all_projects()

    # Broadcast options
    broadcast_options = [
      %{value: "everyone", label: "🌐 Everyone", description: "All supervisors and attachees"},
      %{value: "all_supervisors", label: "📋 All Supervisors", description: "Send to all supervisors"},
      %{value: "all_attachees", label: "👥 All Attachees", description: "Send to all attachees"}
    ]

    # Project-based options
    project_options = Enum.map(projects, fn project ->
      %{
        value: "project_#{project.id}",
        label: "📁 Project: #{project.name}",
        description: "All attachees in this project"
      }
    end)

    # Individual supervisors
    supervisor_options = Enum.map(supervisors, fn user ->
      %{
        value: "supervisor_#{user.id}",
        label: "👤 #{user.username || user.email}",
        description: "Supervisor"
      }
    end)

    # Individual attachees
    attachee_options = Enum.map(attachees, fn attachee ->
      %{
        value: "attachee_#{attachee.id}",
        label: "👤 #{attachee.user.username || attachee.user.email}",
        description: "Attachee - #{attachee.position}"
      }
    end)

    broadcast_options ++ project_options ++ supervisor_options ++ attachee_options
  end

  def get_target_options_for_role("supervisor") do
    attachees = get_all_attachees()
    projects = get_all_projects()

    # Broadcast options
    broadcast_options = [
      %{value: "all_attachees", label: "👥 All Attachees", description: "Send to all attachees"}
    ]

    # Project-based options
    project_options = Enum.map(projects, fn project ->
      %{
        value: "project_#{project.id}",
        label: "📁 Project: #{project.name}",
        description: "All attachees in this project"
      }
    end)

    # Individual attachees
    attachee_options = Enum.map(attachees, fn attachee ->
      %{
        value: "attachee_#{attachee.id}",
        label: "👤 #{attachee.user.username || attachee.user.email}",
        description: "Attachee - #{attachee.position}"
      }
    end)

    broadcast_options ++ project_options ++ attachee_options
  end

  def get_target_options_for_role(_), do: []

  # Helper functions to get data
  defp get_all_supervisors do
    from(u in User,
      where: "supervisor" in u.roles,
      order_by: [asc: u.username]
    )
    |> Repo.all()
  end

  defp get_all_attachees do
    Eams.list_attachees(%{preloads: [:user]})
    |> Enum.sort_by(fn a -> a.user.username || a.user.email end)
  end

  defp get_all_projects do
    Eams.list_projects()
    |> Enum.sort_by(& &1.name)
  end

  def change_announcement(%Announcement{} = announcement, attrs \\ %{}) do
    Announcement.changeset(announcement, attrs)
  end
end
