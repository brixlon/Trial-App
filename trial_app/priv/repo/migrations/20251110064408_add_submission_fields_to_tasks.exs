defmodule TrialApp.Repo.Migrations.AddSubmissionFieldsToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :submission_comment, :text
      add :submission_links, {:array, :string}, default: []
      add :submission_files, {:array, :string}, default: []
    end
  end
end
