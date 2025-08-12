defmodule Mix.Tasks.Db.Tables do
  use Mix.Task
  @shortdoc "Lists non-system tables"
  alias BeaconDbclient.DBClient

  def run(_args) do
    Mix.Task.run("app.start")

    case DBClient.list_tables() do
      list when is_list(list) ->
        if list == [] do
          IO.puts("No tables found")
        else
          Enum.each(list, &IO.puts/1)
        end

      {:error, err} ->
        IO.puts("Error")
        IO.inspect(err)

      other ->
        IO.inspect(other)
    end
  end
end
