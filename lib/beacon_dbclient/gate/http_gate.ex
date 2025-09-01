defmodule BeaconDbclient.Gate.HttpGate do
  # @behaviour :gen_statem 
  require Logger

  def pulse(%{device_id: _dev} = payload) do
    url = Application.fetch_env!(:beacon_dbclient, :gate_url)
    body = Jason.encode!(Map.take(payload, [:reason, :plate, :device_id]))
    headers = [{"content-type", "application/json"}]

    case :hackney.request(:post, url, headers, body, []) do
      {:ok, 200, _h, ref} ->
        :hackney.body(ref)
        :ok

      other ->
        Logger.warning("gate_pulse_failed = #{inspect(other)}")
        :ok
    end
  end
end
