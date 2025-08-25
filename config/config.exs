import Config

config :beacon_dbclient, ecto_repos: [BeaconDbclient.Repo]

config :beacon_dbclient, :gate_client, BeaconDbclient.NoopGate

config :beacon_dbclient, :db,
  host: System.get_env("DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: System.get_env("DB_NAME", "postgres"),
  user: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  ssl: false,
  connect_timeout: 5_000,
  safe_mode: true

config :beacon_dbclient, :mqtt,
  host: System.get_env("MQTT_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("MQTT_PORT") || "1883"),
  client_id: System.get_env("MQTT_CLIENT_ID", "beacon_dbclient"),
  username: System.get_env("MQTT_USER"),
  password: System.get_env("MQTT_PASS"),
  cmd_prefix: "iot/db/cmd/#"

config :beacon_dbclient, BeaconDbclient.Repo,
  url:
    "postgresql://" <>
      URI.encode(System.get_env("DB_USER", "postgres")) <>
      ":" <>
      URI.encode(System.get_env("DB_PASS", "postgres")) <>
      "@" <>
      System.get_env("DB_HOST", "127.0.0.1") <>
      ":" <>
      System.get_env("DB_PORT", "5432") <>
      "/" <> System.get_env("DB_NAME", "postgres"),
  pool_size: String.to_integer(System.get_env("DB_POOL") || "5")
