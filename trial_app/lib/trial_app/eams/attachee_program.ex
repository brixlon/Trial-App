defmodule TrialApp.Eams.AttacheeProgram do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias TrialApp.Repo

  schema "attachee_programs" do
    belongs_to :attachee, TrialApp.Eams.Attachee
    belongs_to :program, TrialApp.Eams.Program

    timestamps()
  end

  def changeset(ap, attrs) do
    ap
    |> cast(attrs, [:attachee_id, :program_id])
    |> validate_required([:attachee_id, :program_id])
    |> validate_one_program_per_attachee()
    |> assoc_constraint(:attachee)
    |> assoc_constraint(:program)
    |> unique_constraint([:attachee_id, :program_id], name: :attachee_programs_attachee_id_program_id_index)
  end

  # Enforce one attachee per program constraint
  defp validate_one_program_per_attachee(changeset) do
    attachee_id = get_change(changeset, :attachee_id) || get_field(changeset, :attachee_id)
    program_id = get_change(changeset, :program_id) || get_field(changeset, :program_id)

    if attachee_id && program_id do
      # Check if attachee is already enrolled in another program
      existing = TrialApp.Repo.one(
        from ap in TrialApp.Eams.AttacheeProgram,
        where: ap.attachee_id == ^attachee_id and ap.program_id != ^program_id
      )

      if existing do
        add_error(changeset, :attachee_id, "attachee can only belong to one program")
      else
        changeset
      end
    else
      changeset
    end
  end
end
