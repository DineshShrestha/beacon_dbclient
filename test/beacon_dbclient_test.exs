defmodule BeaconDbclientTest do
  use ExUnit.Case
  doctest BeaconDbclient

  test "greets the world" do
    assert BeaconDbclient.hello() == :world
  end
end
