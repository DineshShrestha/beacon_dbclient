defmodule Mix.Tasks.Iot.Sim do
  use Mix.Task
  @shortdoc "Simulate an IoT message: mix iot.sim <topic> '<json>'"
  alias BeaconDbclient.Router

  # Accepts: mix iot.sim <topic> '<json...>'
  def run([topic | json_parts]) do
    Mix.Task.run("app.start")

    json = Enum.join(json_parts, " ")

    case Router.handle(topic, json) do
      {:ok, resp} ->
        IO.puts(Jason.encode!(resp, pretty: true))

      {:error, err} ->
        IO.puts(Jason.encode!(%{"ok" => false, "error" => err}, pretty: true))
        System.halt(2)
    end
  end

  # Fallback when args are missing
  def run(_args) do
    IO.puts("usage: mix iot.sim <topic> '<json>'")
  end
end
