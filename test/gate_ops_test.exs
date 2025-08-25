defmodule BeaconDbclient.GateOpsTest do
  use ExUnit.Case, async: false
  alias BeaconDbclient.{Repo, OpsFlag}

  test "stop -> status -> clear" do
    # ensure clean state
    Repo.insert!(%OpsFlag{key: "gate", value: %{"stop" => false}},
      on_conflict: [set: [value: %{"stop" => false}]],
      conflict_target: :key
    )

    # set stop
    Repo.insert!(%OpsFlag{key: "gate", value: %{"stop" => true}},
      on_conflict: [set: [value: %{"stop" => true}]],
      conflict_target: :key
    )

    assert %OpsFlag{value: %{"stop" => true}} = Repo.get_by(OpsFlag, key: "gate")

    # Clear
    Repo.insert!(%OpsFlag{key: "gate", value: %{"stop" => false}},
      on_conflict: [set: [value: %{"stop" => false}]],
      conflict_target: :key
    )

    assert %OpsFlag{value: %{"stop" => false}} = Repo.get_by(OpsFlag, key: "gate")
  end
end
