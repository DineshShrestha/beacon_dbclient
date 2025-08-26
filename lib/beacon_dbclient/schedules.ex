defmodule BeaconDbclient.Schedules do
  alias BeaconDbclient.{Repo}
  alias BeaconDbclient.Schedules.Schedule

  @days ~w(mon tue wed thu fri sat sun)

  def upsert_global(%{"tz" => tz, "weekly" => weekly}) do
    weekly = normalize_weekly(weekly)

    Repo.insert!(%Schedule{key: "global", tz: tz, weekly: weekly},
      on_conflict: [set: [tz: tz, weekly: weekly]],
      conflict_target: :key
    )
  end

  def upsert_global(%{"weekly" => weekly}) do
    upsert_global(%{"tz" => "Europe/Oslo", "weekly" => weekly})
  end

  def get_global, do: Repo.get_by(Schedule, key: "global")

  # now is a DateTime(UTC). Returns true if within any window today.
  def active?(now \\ DateTime.utc_now()) do
    case get_global() do
      nil ->
        true

      %Schedule{tz: tz, weekly: weekly} ->
        {:ok, local} = shift_tz(now, tz)
        day = day_atom(local)
        ranges = Map.get(weekly, day, [])
        within_any?(local, ranges)
    end
  end

  # Helpers
  defp normalize_weekly(weekly) when is_map(weekly) do
    weekly
    |> Enum.map(fn {k, v} -> {normalize_day(k), normalize_ranges(v)} end)
    |> Enum.into(%{})
  end

  defp normalize_day(k) when is_binary(k) do
    k = String.downcase(k)
    if k in @days, do: k, else: raise(ArgumentError, "bad day #{inspect(k)}")
  end

  defp normalize_ranges(ranges) when is_list(ranges) do
    Enum.map(ranges, fn
      [from, to] when is_binary(from) and is_binary(to) -> [from, to]
      bad -> raise ArgumentError, "bad range #{inspect(bad)}"
    end)
  end

  defp shift_tz(%DateTime{} = utc, tz) do
    # Use :calender/timezone database via TzData if available: fallback to naive clock 
    case DateTime.shift_zone(utc, tz) do
      {:ok, local} -> {:ok, local}
      # fallback if tz is'nt available
      _ -> {:ok, utc}
    end
  end

  defp day_atom(%DateTime{calendar: _} = dt) do
    case Date.day_of_week(DateTime.to_date(dt)) do
      1 -> "mon"
      2 -> "tue"
      3 -> "wed"
      4 -> "thu"
      5 -> "fri"
      6 -> "sat"
      7 -> "sun"
    end
  end

  defp within_any?(%DateTime{} = dt, ranges) do
    {h, m, _s} = {dt.hour, dt.minute, dt.second}
    now_min = h * 60 + m

    Enum.any?(ranges, fn [from, to] ->
      {fh, fm} = parse_hhmm(from)
      {th, tm} = parse_hhmm(to)
      from_min = fh * 60 + fm
      to_min = th * 60 + tm
      from_min <= now_min and now_min <= to_min
    end)
  end

  defp parse_hhmm(<<a::binary-size(2), ":", b::binary-size(2)>>),
    do: {String.to_integer(a), String.to_integer(b)}
end
