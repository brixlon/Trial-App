defmodule TrialApp.Repo.Migrations.AddRejectReasonToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :reject_reason, :text
    end
  end
end
