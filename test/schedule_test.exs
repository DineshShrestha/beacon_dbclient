defmodule BeaconDbclient.SchedulesTest do
  use ExUnit.Case, async: false
  alias BeaconDbclient.{Schedules, Repo}
  alias BeaconDbclient.Schedules.Schedule

  test "set and get global schedule" do
    weekly = %{
      "mon" => [["08:00", "18:00"]],
      "tue" => [["08:00", "18:00"]],
      "wed" => [["08:00", "18:00"]],
      "thu" => [["08:00", "18:00"]],
      "fri" => [["08:00", "18:00"]],
      "sat" => [],
      "sun" => []
    }

    s = Schedules.upsert_global(%{"tz" => "Europe/Oslo", "weekly" => weekly})
    assert %Schedule{weekly: ^weekly} = s

    assert Schedules.get_global() |> Map.get(:weekly) == weekly
  end
end
