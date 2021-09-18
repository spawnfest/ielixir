defmodule IElixir.Kernel.Socket.Pub do
  defmacro __using__(opts) do
    channel_name = Keyword.get(opts, :name)

    quote do
      require Logger
      use GenServer

      def start_link(%IElixir.Kernel.Socket.Config{} = channel_config) do
        GenServer.start_link(__MODULE__, channel_config, name: __MODULE__)
      end

      # API
      def init(%IElixir.Kernel.Socket.Config{connection_data: connection_data}) do
        Logger.debug("Starting channel #{unquote(channel_name)}")

        {
          :ok,
          %{
            channel:
              IElixir.Kernel.Wire.make_channel(
                connection_data,
                unquote(channel_name),
                :pub
              )
          }
        }
      end

      @spec publish(packet :: IElixir.Kernel.Wire.Packet.t()) :: :ok
      def publish(packet) do
        packet
        |> IElixir.Kernel.Wire.Packet.encode()
        |> publish_raw()
      end

      @spec publish_raw(raw_packet :: IElixir.Kernel.Connection.Wire.raw_packet()) :: :ok
      def publish_raw(raw_packet) when is_binary(raw_packet) do
        GenServer.call(__MODULE__, {:"$zmq_publish", raw_packet})
      end

      def publish_raw(raw_packet) when is_list(raw_packet) do
        GenServer.call(__MODULE__, {:"$zmq_publish_multipart", raw_packet})
      end

      def handle_call({:"$zmq_publish", raw_packet}, _from, %{channel: channel} = state) do
        {
          :reply,
          :chumak.send(channel, raw_packet),
          state
        }
      end

      def handle_call({:"$zmq_publish_multipart", raw_packet}, _from, %{channel: channel} = state) do
        {
          :reply,
          :chumak.send_multipart(channel, raw_packet),
          state
        }
      end

      def terminate(_reason, _) do
        Logger.debug("Shutdown #{unquote(channel_name)} channel")
      end
    end
  end
end
