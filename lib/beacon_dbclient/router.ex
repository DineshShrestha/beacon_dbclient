defmodule BeaconDbclient.Router do
  alias BeaconDbclient.DBClient
  @spec handle(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def handle(topic, payload_json) do
    with {:ok, req} <- decode(payload_json) do
      route(topic, req)
    end
  end

  defp decode(json) do
    case JSON.decode(json) do
      {:ok, m} when is_map(m) -> {:ok, m}
      _ -> {:error, "invalid_json"}
    end
  end

  defp route("iot/db/cmd/check", req) do
    case DBClient.query("select now() as ts, current_user") do
      {:ok, %{columns: cols, rows: [row | _]}} ->
        {:ok, ok(req, Enum.zip(cols, row) |> Map.new())}

      {:error, err} ->
        {:error, err_to_string(err)}
    end
  end

  defp route("iot/db/cmd/tables", req) do
    case DBClient.list_tables() do
      list when is_list(list) -> {:ok, ok(req, %{tables: list})}
      {:error, err} -> {:error, err_to_string(err)}
      other -> {:error, "Unexpected: #{inspect(other)}"}
    end
  end

  defp route("iot/db/cmd/query", %{"sql" => sql} = req) do
    params = Map.get(req, "params", [])

    case DBClient.query(sql, params) do
      {:ok, res} -> {:ok, ok(req, res)}
      {:error, err} -> {:error, err_to_string(err)}
    end
  end

  defp route(other, _req), do: {:error, "unknown_topic: #{other}"}

  defp ok(req, data),
    do: %{"ok" => true, "device_id" => Map.get(req, "device_id"), "data" => data}

  defp err_to_string(%Postgrex.Error{message: msg}), do: msg
  defp err_to_string(other), do: inspect(other)
end
