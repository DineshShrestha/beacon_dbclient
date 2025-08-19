defmodule BeaconDbclient.Router do
  alias BeaconDbclient.DBClient
  @spec handle(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def handle(topic, payload_json) do
    case Jason.decode(payload_json) do
      {:ok, req} ->
        try do
          route(topic, req)
        rescue
          e in RuntimeError ->
            {:error, e.message}

          e ->
            # fallback for unexpected errors
            {:error, Exception.message(e)}
        end

      _ ->
        {:error, "invalid_json"}
    end
  end

  #   defp decode(json) do
  #     case JSON.decode(json) do
  #       {:ok, m} when is_map(m) -> {:ok, m}
  #       _ -> {:error, "invalid_json"}
  #     end
  #   end

  defp route("iot/db/cmd/check", req) do
    case DBClient.query("select now() as ts, current_user") do
      {:ok, %{columns: cols, rows: [row | _]}} ->
        {:ok, ok(req, Enum.zip(cols, row) |> Map.new(), reply_topic("iot/db/cmd/check"))}

      {:error, err} ->
        {:error, err_to_string(err)}
    end
  end

  defp route("iot/db/cmd/tables", req) do
    case DBClient.list_tables() do
      list when is_list(list) -> {:ok, ok(req, %{tables: list}, reply_topic("iot/db/cmd/tables"))}
      {:error, err} -> {:error, err_to_string(err)}
      other -> {:error, "Unexpected: #{inspect(other)}"}
    end
  end

  defp route("iot/db/cmd/query", %{"sql" => sql} = req) do
    params = Map.get(req, "params", [])
    safe = Map.get(req, "safe", true)

    case DBClient.query(sql, params, safe: safe) do
      {:ok, res} -> {:ok, ok(req, res, reply_topic("iot/db/cmd/query"))}
      {:error, err} -> {:error, err_to_string(err)}
    end
  end

  # Upsert plate:
  defp route("iot/db/cmd/plate.upsert", %{"plate" => _plate} = req) do
    attrs = Map.take(req, ["plate", "owner", "enabled", "valid_from", "valid_to"])

    case BeaconDbclient.Plates.upsert(attrs) do
      {:ok, p} ->
        {:ok,
         ok(
           req,
           %{id: p.id, plate: p.plate, owner: p.owner, enabled: p.enabled},
           reply_topic("iot/db/cmd/plate.upsert")
         )}

      {:error, changeset} ->
        {:error, inspect(changeset.errors)}
    end
  end

  # Check plate:
  defp route("iot/db/cmd/plate.check", %{"plate" => plate} = req) do
    case BeaconDbclient.Plates.check(plate) do
      {:allow, reason} ->
        {:ok,
         ok(req, %{decision: "allow", reason: reason}, reply_topic("iot/db/cmd/plate.check"))}

      {:deny, reason} ->
        {:ok, ok(req, %{decision: "deny", reason: reason}, reply_topic("iot/db/cmd/plate.check"))}
    end
  end



  # Operator wants to open gate
  defp route("iot/db/cmd/gate.open", %{"device_id"=> dev}) do
    # check if stop flag is active
    case get_stop_flag() do
      true -> 
        {:error, "gate.stop active, cannot open"}
      false -> 
        # here you would trigger relay/pulse in real system
        {:ok, %{decision: "manual_open", device_id: dev}}
    end
  end
 
  # Operator emergency stop
  defp route("iot/db/cmd/gate.stop", %{"device_id"=> dev}) do
    set_stop_flag(true) 
    {:ok, %{decision: "stopped", device_id: dev}}
  end

   # gate.status -> report current stop state
   defp route("iot/db/cmd/gate.status", %{"device_id"=> _dev} = req) do
    status = if get_stop_flag(), do: "stopped", else: "ready"
    {:ok, ok(req, %{status: status}, reply_topic("iot/db/cmd/gate.status"))}
  end
  # gate.clear → lift emergency stop
  defp route("iot/db/cmd/gate.clear", %{"device_id"=> _dev} = req) do
    set_stop_flag(false)
    {:ok, ok(req, %{decision: "cleared"}, reply_topic("iot/db/cmd/gate.clear"))}
  end
  defp route(other, _req), do: {:error, "unknown_topic: #{other}"}
  defp get_stop_flag do
    alias BeaconDbclient.{Repo, OpsFlag}
    case Repo.get_by(OpsFlag, key: "gate") do
      nil -> false
      flag -> Map.get(flag.value, "stop", false)
    end
  end
  defp set_stop_flag(val) do
    alias BeaconDbclient.{Repo, OpsFlag}
    Repo.insert!(
      %OpsFlag{key: "gate", value: %{"stop"=> val}},
      on_conflict: [set: [value: %{"stop"=> val}]],
      conflict_target: :key
    )
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
  defp reply_topic(_other), do: "iot/db/resp/unknown"
end
