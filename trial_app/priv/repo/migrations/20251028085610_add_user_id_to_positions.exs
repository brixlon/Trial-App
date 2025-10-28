defmodule TrialApp.Repo.Migrations.AddUserIdToPositions do
  use Ecto.Migration

  def change do
    alter table(:positions) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end
  end
end
