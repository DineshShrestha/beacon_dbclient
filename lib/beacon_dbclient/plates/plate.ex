defmodule BeaconDbclient.Plates.Plate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "plates" do
    field(:plate, :string)
    field(:owner, :string)
    field(:enabled, :boolean, default: true)
    field(:valid_from, :utc_datetime_usec)
    field(:valid_to, :utc_datetime_usec)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:plate, :owner, :enabled, :valid_from, :valid_to])
    |> validate_required([:plate])
    |> update_change(:plate, &String.upcase/1)
    |> unique_constraint(:plate)
  end
end
