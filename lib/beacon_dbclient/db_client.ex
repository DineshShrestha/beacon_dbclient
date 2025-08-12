defmodule BeaconDbclient.DBClient do
  alias BeaconDbclient.DBSafe

  defp cfg, do: Application.fetch_env!(:beacon_dbclient, :db)

  defp connect! do
    c = cfg()

    opts = [
      hostname: c[:host],
      port: c[:port],
      database: c[:database],
      username: c[:user],
      password: c[:password],
      ssl: !!c[:ssl],
      timeout: c[:connect_timeout] || 5_000
    ]

    {:ok, pid} = Postgrex.start_link(opts)
    pid
  end

  def query(sql, params \\ [], opts \\ []) do
    safe? = Keyword.get(opts, :safe, cfg()[:safe_mode])
    DBSafe.check!(sql, safe?)

    pid = connect!()
    result = Postgrex.query(pid, sql, params)
    # <- replace Postgrex.stop/1
    _ = GenServer.stop(pid)

    case result do
      {:ok, %Postgrex.Result{columns: cols, rows: rows}} -> {:ok, %{columns: cols, rows: rows}}
      {:error, %Postgrex.Error{} = e} -> {:error, e}
      other -> other
    end
  end

  def list_tables do
    sql = """
    select table_schema, table_name from information_schema.tables where table_type='BASE TABLE' and table_schema not in ('pg_catalog', 'information_schema')
    order by table_schema, table_name
    """

    case query(sql) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, name] -> "#{schema}.#{name}" end)

      other ->
        other
    end
  end
end
