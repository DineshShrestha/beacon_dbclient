defmodule BeaconDbclient.RouterGateTest do
  use ExUnit.Case, async: false
  alias BeaconDbclient.{Router, Repo, OpsFlag, Plates}

  setup do
    # reset stop flag
    Repo.insert!(%OpsFlag{key: "gate", value: %{"stop" => false}},
      on_conflict: [set: [value: %{"stop" => false}]],
      conflict_target: :key
    )

    :ok
  end

  test "plate.check allows when plate exists and not stopped" do
    {:ok, _} = Plates.upsert(%{"plate" => "AB12345", "enabled" => true})

    topic = "iot/db/cmd/plate.check"
    req = ~s({"device_id":"edge-1","plate":"ab12345"})
    assert {:ok, resp} = Router.handle(topic, req)
    assert resp["ok"] == true
    assert resp["data"][:decision] == "allow"
  end

  test "plate.check denies when stopped" do
    Repo.insert!(%OpsFlag{key: "gate", value: %{"stop" => true}},
      on_conflict: [set: [value: %{"stop" => true}]],
      conflict_target: :key
    )

    {:ok, _} = Plates.upsert(%{"plate" => "AB12345", "enabled" => true})
    topic = "iot/db/cmd/plate.check"
    req = ~s({"device_id":"edge-1","plate":"AB12345"})
    assert {:ok, resp} = Router.handle(topic, req)
    assert resp["data"][:decision] == "deny"
    assert resp["data"][:reason] in [:stopped, "stopped"]
  end
end
