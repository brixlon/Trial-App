defmodule TrialAppWeb.DownloadController do
  use TrialAppWeb, :controller
  require Logger

  def download_task_submission(conn, %{"filename" => filename}) do
    current_scope = conn.assigns.current_scope
    current_user = current_scope.user

    # Try multiple possible paths where uploads might be stored
    possible_paths = [
      Path.join([File.cwd!(), "priv", "priv", "static", "uploads", "task_submissions", filename]),
      Path.join([File.cwd!(), "priv", "static", "uploads", "task_submissions", filename]),
      Path.join([File.cwd!(), "uploads", "task_submissions", filename]),
      Path.join(["uploads", "task_submissions", filename])
    ]

    file_path = Enum.find(possible_paths, &File.exists?/1)

    Logger.info("Download attempt: #{filename} by user #{current_user.id} (role: #{current_scope.active_role})")

    if file_path do
      Logger.debug("File found at: #{file_path}")

      # Optional: Add authorization logic here
      # For example, verify that the user has permission to download this file
      # based on their role (supervisor, admin, or the attachee who uploaded it)

      conn
      |> put_resp_content_type(get_content_type(filename))
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_file(200, file_path)
    else
      Logger.warning("File not found in any of the expected locations for: #{filename}")
      Logger.debug("Searched paths: #{inspect(possible_paths)}")

      conn
      |> put_status(:not_found)
      |> put_view(html: TrialAppWeb.ErrorHTML)
      |> render(:"404")
    end
  end

  # Helper function to determine content type based on file extension
  defp get_content_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".pdf" -> "application/pdf"
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".doc" -> "application/msword"
      ".docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ".xls" -> "application/vnd.ms-excel"
      ".xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ".zip" -> "application/zip"
      ".txt" -> "text/plain"
      _ -> "application/octet-stream"
    end
  end
end
