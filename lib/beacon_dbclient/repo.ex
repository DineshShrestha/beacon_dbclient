defmodule BeaconDbclient.Repo do
  use Ecto.Repo,
    otp_app: :beacon_dbclient,
    adapter: Ecto.Adapters.Postgres
end
