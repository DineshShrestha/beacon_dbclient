import Config

config :beacon_dbclient, :db,
  host: System.get_env("DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: System.get_env("DB_NAME", "postgres"),
  user: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  ssl: false,
  connect_timeout: 5_000,
  safe_mode: true
