defmodule BeaconDbclient.Events do
  alias BeaconDbclient.{Repo}
  alias BeaconDbclient.Events.Event

  @spec log(map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def log(attrs), do: %Event{} |> Event.changeset(attrs) |> Repo.insert()
end
