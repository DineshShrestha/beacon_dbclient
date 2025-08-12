defmodule Mix.Tasks.Db.Check do
  use Mix.Task
  @shortdoc "Checks DB connectivity"
  # <- note: Dbclient
  alias BeaconDbclient.DBClient

  def run(_args) do
    Mix.Task.run("app.start")

    case DBClient.query("select now() as ts, current_user") do
      {:ok, %{columns: cols, rows: [row | _]}} ->
        IO.puts("✅ DB OK")
        IO.inspect(Enum.zip(cols, row) |> Map.new())

      {:error, err} ->
        IO.puts("❌ DB ERROR")
        IO.inspect(err)
        System.halt(2)
    end
  end
end
