defmodule BeaconDbclient.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]
  schema "events" do
    field(:device_id, :string)
    field(:plate, :string)
    field(:confidence, :float)
    field(:snapshot_url, :string)
    field(:decision, :string)
    field(:reason, :string)
    field(:meta, :map, default: %{})
    timestamps()
  end

  def changeset(e, attrs) do
    e
    |> cast(attrs, [:device_id, :plate, :confidence, :snapshot_url, :decision, :reason, :meta])
    |> validate_required([:device_id, :plate, :decision])
    |> update_change(:plate, &String.upcase/1)
  end
end
