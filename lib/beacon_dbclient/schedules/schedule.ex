defmodule BeaconDbclient.Schedules.Schedule do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime_usec]

  schema "schedules" do
    field(:key, :string)
    field(:tz, :string, default: "Europe/Oslo")
    field(:weekly, :map, default: %{})
    timestamps()
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:key, :tz, :weekly])
    |> validate_required([:key, :tz, :weekly])
  end
end
