defmodule TrialApp.Eams.AttacheeProgram do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attachee_programs" do
    belongs_to :attachee, TrialApp.Eams.Attachee
    belongs_to :program, TrialApp.Eams.Program

    timestamps()
  end

  def changeset(ap, attrs) do
    ap
    |> cast(attrs, [:attachee_id, :program_id])
    |> validate_required([:attachee_id, :program_id])
    |> assoc_constraint(:attachee)
    |> assoc_constraint(:program)
    |> unique_constraint([:attachee_id, :program_id], name: :attachee_programs_attachee_id_program_id_index)
  end
end
