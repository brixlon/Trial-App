# lib/trial_app_web/plugs/handle_invalid_query.ex
defmodule TrialAppWeb.Plugs.HandleInvalidQuery do
  def init(opts), do: opts

  def call(conn, _opts) do
    # Try to fetch query params, but rescue from invalid UTF-8 errors
    try do
      Plug.Conn.fetch_query_params(conn)
    rescue
      exception in Plug.Conn.InvalidQueryError ->
        # Log the error and continue with empty params
        require Logger
        Logger.warning("Invalid query parameters detected and ignored: #{exception.message}")

        # Continue without query params
        %{conn | query_params: %{}, params: %{}}
    end
  end
end
