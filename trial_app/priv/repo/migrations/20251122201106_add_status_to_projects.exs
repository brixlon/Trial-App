defmodule TrialApp.Repo.Migrations.AddStatusToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :status, :string, default: "pending", null: false
    end
  end
end
