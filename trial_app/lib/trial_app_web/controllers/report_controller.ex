defmodule TrialAppWeb.ReportController do
  use TrialAppWeb, :controller
  alias TrialApp.Reports

  def download(conn, %{"id" => report_id}) do
    report = Reports.get_report!(report_id)

    # CRITICAL FIX: Check if the file path is present and the file exists on the disk.
    file_path = report.file_path

    if file_path && File.exists?(file_path) do
      # If using local file storage:
      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{report.file_name}\"")
      |> send_file(200, file_path)
    else
      # Handle case where file is missing in DB or on disk.
      # Return a 404 response with a simple message.
      conn
      |> put_status(:not_found)
      |> put_resp_content_type("text/plain")
      |> send_resp(:not_found, "Error: The requested report file was not found on the server.")
    end
  end
end
