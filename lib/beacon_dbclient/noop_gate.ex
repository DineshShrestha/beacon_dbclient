defmodule BeaconDbclient.NoopGate do
  @moduledoc false
  @spec pulse(map()) :: :ok
  def pulse(_payload), do: :ok
end
