defmodule BeaconDbclient.MQTT do
  @moduledoc false
  use GenServer
  require Logger

  alias BeaconDbclient.Router

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def init(:ok) do
    cfg = Application.fetch_env!(:beacon_dbclient, :mqtt)

    {:ok, _pid} =
      Tortoise311.Connection.start_link(
        client_id: cfg[:client_id],
        server: {Tortoise311.Transport.Tcp, host: cfg[:host], port: cfg[:port]},
        handler:
          {BeaconDbclient.MQTT.Handler,
           [client_id: cfg[:client_id], cmd_prefix: cfg[:cmd_prefix]]},
        subscriptions: [{cfg[:cmd_prefix], 0}],
        user_name: cfg[:username],
        password: cfg[:password],
        keep_alive: 30
      )

    Logger.info("MQTT connected tortoise311 and suscribed to #{cfg[:cmd_prefix]}")

    {:ok, %{client_id: cfg[:client_id]}}
  end

  # Tortoise handler lives nested for simplicity
  defmodule Handler do
    @behaviour Tortoise311.Handler
    require Logger
    alias BeaconDbclient.Router

    def init(args), do: {:ok, Map.new(args)}

    def connection(:up, %{client_id: cid, cmd_prefix: prefix} = state) do
      Logger.info("MQTT connection is up; (re)subscribing to #{prefix}")
      # Explicit (re)subscribe on connect
      {:ok, _ref} = Tortoise311.Connection.subscribe(cid, [{prefix, 0}])
      {:ok, state}
    end

    def connection(_status, state), do: {:ok, state}

    # def handle_message(topic_tokens, payload, %{client_id: cid} = state) do
    #   topic = Enum.join(topic_tokens, "/")
    #   payload_bin = IO.iodata_to_binary(payload)
    #   Logger.debug("<< MQTT recv topic=#{topic} bytes=#{byte_size(payload_bin)}")

    #   reply_json =
    #     case Router.handle(topic, payload_bin) do
    #       {:ok, resp} -> Jason.encode!(resp)
    #       {:error, err} -> Jason.encode!(%{"ok" => false, "error" => err})
    #     end

    #   reply_topic = infer_reply_topic(topic)
    #   Logger.debug(">> MQTT send topic=#{reply_topic} bytes=#{byte_size(reply_json)}")

    #   # publish using client_id
    #   case Tortoise311.publish(cid, reply_topic, reply_json, qos: 0) do
    #     :ok -> :ok
    #     other -> Logger.error("publish failed: #{inspect(other)}")
    #   end

    #   {:ok, state}
    # end
    def handle_message(topic_tokens, payload, %{client_id: cid} = state) do
      topic = Enum.join(topic_tokens, "/")
      bin = IO.iodata_to_binary(payload)

      Logger.debug("<< MQTT recv topic=#{topic} bytes=#{byte_size(bin)} payload=#{bin}")

      reply_json =
        case Router.handle(topic, bin) do
          {:ok, resp} -> Jason.encode!(resp)
          {:error, err} -> Jason.encode!(%{"ok" => false, "error" => err})
        end

      reply_topic = infer_reply_topic(topic)
      Logger.debug(">> MQTT send topic=#{reply_topic} bytes=#{byte_size(reply_json)}")

      case Tortoise311.publish(cid, reply_topic, reply_json, qos: 0) do
        :ok -> :ok
        other -> Logger.error("publish failed: #{inspect(other)}")
      end

      {:ok, state}
    end

    def subscription(_status, _topic, state), do: {:ok, state}
    def terminate(_reason, _state), do: :ok

    defp infer_reply_topic("iot/db/cmd" <> cmd), do: "iot/db/resp" <> cmd
    defp infer_reply_topic(_), do: "iot/db/resp/unknown"
  end
end
