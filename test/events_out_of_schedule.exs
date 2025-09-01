defmodule BeaconDbclient.EventsOutOfScheduleTest do
  use ExUnit.Case, async: false
  alias BeaconDbclient.{Repo, OpsFlag, Router, Events.Event, Schedules}

  setup do
    # not stopped
    Repo.insert!(%OpsFlag{key: "gate", value: %{"stop" => false}},
      on_conflict: [set: [value: %{"stop" => false}]],
      conflict_target: :key
    )

    # set schedule to CLOSED (empty)
    Schedules.upsert_global(%{"weekly" => %{}, "tz" => "Europe/Oslo"})
    :ok
  end

  test "lpr event denies and logs out_of_schedule" do
    topic = "iot/lpr/event"
    req = ~s({"device_id":"edge-1","plate":"AB12345","confidence":0.9})
    assert {:ok, resp} = Router.handle(topic, req)
    assert resp["data"][:decision] == "deny"
    assert resp["data"][:reason] in [:out_of_schedule, "out_of_schedule"]

    # ensure event persisted with reason
    last =
      Event
      |> Ecto.Query.order_by(desc: :inserted_at)
      |> Ecto.Query.limit(1)
      |> Repo.one()

    assert last.reason == "out_of_schedule"
    assert last.decision == "deny"
  end
end
