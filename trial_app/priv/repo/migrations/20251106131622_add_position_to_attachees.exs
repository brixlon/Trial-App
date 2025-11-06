defmodule TrialApp.Repo.Migrations.AddPositionToAttachees do
  use Ecto.Migration

  def change do
    alter table(:attachees) do
      add :position, :string, default: "Software Developer Attachee"
    end

    # Back-fill existing rows
    execute """
    UPDATE attachees SET position = 'Software Developer Attachee' WHERE position IS NULL;
    """
  end
end
