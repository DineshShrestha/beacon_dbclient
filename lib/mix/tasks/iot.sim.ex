defmodule Mix.Tasks.Iot.Sim do
  use Mix.Task
  @shortdoc "Simulate an IoT message: mix iox.sim <topic> '<json>'"
  alias BeaconDbclient.Router

  def run(topic, json) do
    Mix.Task.run("app.start")

    case Router.handle(topic, json) do
      {:ok, resp} ->
        IO.puts(Jason.encode!(resp, pretty: true))

      {:error, err} ->
        IO.puts(Jason.encode!(%{"ok" => false, "error" => err}, pretty: true))
        System.halt(2)
    end
  end

  def run(_args) do
    IO.puts("usage: mix iot.sim <topic> '<json>'")
  end
end
