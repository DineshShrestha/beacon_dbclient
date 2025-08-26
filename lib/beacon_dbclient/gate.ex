defmodule BeaconDbclient.Gate do
  @moduledoc false
  # Stub for now; swap to real adapter (HTTP relay/NVR) later.
  @spec pulse(map()) :: :ok
  def pulse(_attrs), do: :ok
end
