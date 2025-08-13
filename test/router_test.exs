defmodule BeaconDbclient.RouterTest do
  use ExUnit.Case, async: true
  alias BeaconDbclient.Router

  test "query happy path (select 1)" do
    topic = "iot/db/cmd/query"
    req = ~s({"device_id":"edge-1","sql":"select 1 as one"})

    assert {:ok, resp} = Router.handle(topic, req)

    assert resp["ok"] == true
    assert resp["device_id"] == "edge-1"
    assert resp["reply_topic"] == "iot/db/resp/query"

    data = resp["data"]
    assert data[:command] == :select
    assert data[:columns] == ["one"]
    assert data[:rows] == [[1]]
  end

  test "blocked destructive without safe=true" do
    topic = "iot/db/cmd/query"
    req = ~s({"device_id":"edge-1","sql":"delete from demo"})
    assert {:error, msg} = Router.handle(topic, req)
    assert msg =~ "Blocked dangerous query"
  end
end
