defmodule BeaconDbclient.Router do
  @moduledoc false
  alias BeaconDbclient.DBClient
  alias BeaconDbclient.{Repo, OpsFlag}

  @spec handle(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def handle(topic, payload_json) do
    case Jason.decode(payload_json) do
      {:ok, req} ->
        try do
          route(topic, req)
        rescue
          e in RuntimeError -> {:error, e.message}
          e -> {:error, Exception.message(e)}
        end

      _ ->
        {:error, "invalid_json"}
    end
  end

  # --- ROUTES: specific first, catch-all last ---

  # Health check (DB time + current_user)
  defp route("iot/db/cmd/check", req) do
    case DBClient.query("select now() as ts, current_user") do
      {:ok, %{columns: cols, rows: [row | _]}} ->
        data = Enum.zip(cols, row) |> Map.new()
        {:ok, ok(req, data, reply_topic("iot/db/cmd/check"))}

      {:error, err} ->
        {:error, err_to_string(err)}
    end
  end

  # List tables
  defp route("iot/db/cmd/tables", req) do
    case DBClient.list_tables() do
      list when is_list(list) ->
        {:ok, ok(req, %{tables: list}, reply_topic("iot/db/cmd/tables"))}

      {:error, err} ->
        {:error, err_to_string(err)}

      other ->
        {:error, "Unexpected: #{inspect(other)}"}
    end
  end

  # SQL query (safe by default)
  defp route("iot/db/cmd/query", %{"sql" => sql} = req) do
    params = Map.get(req, "params", [])
    safe = Map.get(req, "safe", true)

    case DBClient.query(sql, params, safe: safe) do
      {:ok, res} -> {:ok, ok(req, res, reply_topic("iot/db/cmd/query"))}
      {:error, err} -> {:error, err_to_string(err)}
    end
  end

  # Plate upsert
  defp route("iot/db/cmd/plate.upsert", %{"plate" => _} = req) do
    attrs = Map.take(req, ["plate", "owner", "enabled", "valid_from", "valid_to"])

    case BeaconDbclient.Plates.upsert(attrs) do
      {:ok, p} ->
        data = %{id: p.id, plate: p.plate, owner: p.owner, enabled: p.enabled}
        {:ok, ok(req, data, reply_topic("iot/db/cmd/plate.upsert"))}

      {:error, changeset} ->
        {:error, inspect(changeset.errors)}
    end
  end

  # Plate check — STOP and SCHEDULE enforced before plate DB check
  defp route("iot/db/cmd/plate.check", %{"plate" => plate} = req) do
    dev = Map.get(req, "device_id")

    cond do
      get_stop_flag() ->
        {:ok,
         ok(req, %{decision: "deny", reason: :stopped}, reply_topic("iot/db/cmd/plate.check"))}

      not BeaconDbclient.Schedules.active?() ->
        {:ok,
         ok(
           req,
           %{decision: "deny", reason: :out_of_schedule},
           reply_topic("iot/db/cmd/plate.check")
         )}

      true ->
        case BeaconDbclient.Plates.check(plate) do
          {:allow, reason} ->
            _ = maybe_pulse(%{reason: reason, plate: plate, device_id: dev})

            {:ok,
             ok(req, %{decision: "allow", reason: reason}, reply_topic("iot/db/cmd/plate.check"))}

          {:deny, reason} ->
            {:ok,
             ok(req, %{decision: "deny", reason: reason}, reply_topic("iot/db/cmd/plate.check"))}
        end
    end
  end

  # Gate: manual open (respect stop)
  defp route("iot/db/cmd/gate.open", %{"device_id" => dev} = req) do
    if get_stop_flag() do
      {:ok, ok(req, %{decision: "deny", reason: :stopped}, reply_topic("iot/db/cmd/gate.open"))}
    else
      _ = maybe_pulse(%{reason: :manual_open, plate: nil, device_id: dev})

      {:ok,
       ok(req, %{decision: "manual_open", device_id: dev}, reply_topic("iot/db/cmd/gate.open"))}
    end
  end

  # Gate: stop / status / clear
  defp route("iot/db/cmd/gate.stop", %{"device_id" => _} = req) do
    :ok = set_stop_flag(true)
    {:ok, ok(req, %{decision: "stopped"}, reply_topic("iot/db/cmd/gate.stop"))}
  end

  defp route("iot/db/cmd/gate.status", %{"device_id" => _} = req) do
    status = if get_stop_flag(), do: "stopped", else: "ready"
    {:ok, ok(req, %{status: status}, reply_topic("iot/db/cmd/gate.status"))}
  end

  defp route("iot/db/cmd/gate.clear", %{"device_id" => _} = req) do
    :ok = set_stop_flag(false)
    {:ok, ok(req, %{decision: "cleared"}, reply_topic("iot/db/cmd/gate.clear"))}
  end

  # LPR event ingestion (log decision; pulse on allow)
  defp route("iot/lpr/event", %{"device_id" => dev, "plate" => plate} = req) do
    conf = Map.get(req, "confidence")
    snap = Map.get(req, "snapshot_url")

    cond do
      get_stop_flag() ->
        _ =
          BeaconDbclient.Events.log(%{
            device_id: dev,
            plate: plate,
            confidence: conf,
            snapshot_url: snap,
            decision: "deny",
            reason: "stopped",
            meta: req
          })

        {:ok, ok(req, %{decision: "deny", reason: :stopped}, reply_topic("iot/lpr/event"))}

      not BeaconDbclient.Schedules.active?() ->
        _ =
          BeaconDbclient.Events.log(%{
            device_id: dev,
            plate: plate,
            confidence: conf,
            snapshot_url: snap,
            decision: "deny",
            reason: "out_of_schedule",
            meta: req
          })

        {:ok,
         ok(req, %{decision: "deny", reason: :out_of_schedule}, reply_topic("iot/lpr/event"))}

      true ->
        case BeaconDbclient.Plates.check(plate) do
          {:allow, reason} ->
            _ = maybe_pulse(%{reason: reason, plate: plate, device_id: dev})

            _ =
              BeaconDbclient.Events.log(%{
                device_id: dev,
                plate: plate,
                confidence: conf,
                snapshot_url: snap,
                decision: "allow",
                reason: to_string(reason),
                meta: req
              })

            {:ok, ok(req, %{decision: "allow", reason: reason}, reply_topic("iot/lpr/event"))}

          {:deny, reason} ->
            _ =
              BeaconDbclient.Events.log(%{
                device_id: dev,
                plate: plate,
                confidence: conf,
                snapshot_url: snap,
                decision: "deny",
                reason: to_string(reason),
                meta: req
              })

            {:ok, ok(req, %{decision: "deny", reason: reason}, reply_topic("iot/lpr/event"))}
        end
    end
  end

  # Set global schedule
  defp route("iot/db/cmd/schedule.set", %{"weekly" => weekly} = req) do
    attrs = %{"tz" => Map.get(req, "tz", "Europe/Oslo"), "weekly" => weekly}

    try do
      s = BeaconDbclient.Schedules.upsert_global(attrs)
      {:ok, ok(req, %{tz: s.tz, weekly: s.weekly}, reply_topic("iot/db/cmd/schedule.set"))}
    rescue
      e -> {:error, "bad_schedule: #{Exception.message(e)}"}
    end
  end

  # Get global schedule
  defp route("iot/db/cmd/schedule.get", req) do
    case BeaconDbclient.Schedules.get_global() do
      nil ->
        {:ok, ok(req, %{tz: "Europe/Oslo", weekly: %{}}, reply_topic("iot/db/cmd/schedule.get"))}

      s ->
        {:ok, ok(req, %{tz: s.tz, weekly: s.weekly}, reply_topic("iot/db/cmd/schedule.get"))}
    end
  end

  # Catch-all LAST
  defp route(other, _req), do: {:error, "unknown_topic: #{other}"}

  # --- Helpers ---

  defp get_stop_flag do
    case Repo.get_by(OpsFlag, key: "gate") do
      nil -> false
      %OpsFlag{value: value} -> Map.get(value, "stop", false)
    end
  end

  defp set_stop_flag(val) do
    _ =
      Repo.insert!(
        %OpsFlag{key: "gate", value: %{"stop" => val}},
        on_conflict: [set: [value: %{"stop" => val}]],
        conflict_target: :key
      )

    :ok
  end

  defp ok(req, data, reply_topic),
    do: %{
      "ok" => true,
      "device_id" => Map.get(req, "device_id"),
      "data" => data,
      "reply_topic" => reply_topic
    }

  defp err_to_string(%Postgrex.Error{message: msg}), do: msg
  defp err_to_string(other), do: inspect(other)

  defp reply_topic("iot/db/cmd" <> cmd), do: "iot/db/resp" <> cmd
  defp reply_topic("iot/lpr/event"), do: "iot/resp/lpr/event"
  defp reply_topic(_other), do: "iot/db/resp/unknown"

  # Safe, pluggable pulse (does nothing if adapter missing)
  defp maybe_pulse(payload) do
    mod = Application.get_env(:beacon_dbclient, :gate_client, BeaconDbclient.NoopGate)

    cond do
      is_atom(mod) and Code.ensure_loaded?(mod) and function_exported?(mod, :pulse, 1) ->
        try do
          mod.pulse(payload)
        rescue
          _ -> :ok
        end

      true ->
        :ok
    end
  end
end
