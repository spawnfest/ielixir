defmodule IElixir.Kernel.Socket.Router do
  alias IElixir.Kernel.Wire
  alias IElixir.Kernel.Wire.Packet

  @callback handle_packet(packet :: Packet.t(), channel :: Wire.channel()) ::
              Packet.t() | nil | {Packet.t() | nil, (() -> :ok)}
  @callback handle_raw_packet(packet :: Wire.raw_packet(), channel :: pid()) ::
              Wire.raw_packet() | nil | {Wire.raw_packet() | nil, (() -> :ok)}

  defmacro __using__(opts) do
    channel_name = Keyword.get(opts, :name)

    quote do
      require Logger
      use GenServer
      @behaviour unquote(__MODULE__)

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
                :router
              )
          },
          {:continue, []}
        }
      end

      def handle_continue(_, %{channel: socket} = state) do
        get_req(socket)
        {:noreply, state}
      end

      def handle_info(
            {:zmq, :ok, packet},
            %{
              channel: channel
            } = state
          ) do
        Logger.debug("Got #{unquote(channel_name)} packet: #{packet}")

        case handle_raw_packet(packet, channel) do
          nil ->
            :do_nothing

          {nil, after_callback} ->
            after_callback.()

          {reply, after_callback} ->
            :chumak.send_multipart(channel, reply)
            after_callback.()

          reply when is_list(reply) ->
            :chumak.send_multipart(channel, reply)
            # No callback
        end

        get_req(channel)
        {:noreply, state}
      end

      def handle_info(msg, state) do
        Logger.warn("Got unexpected packet on #{__MODULE__} process: #{inspect(msg)}")
        {:noreply, state}
      end

      def terminate(_reason, _) do
        Logger.debug("Shutdown #{unquote(channel_name)} channel")
      end

      defp get_req(socket) do
        parent = self()

        spawn_link(fn ->
          case :chumak.recv_multipart(socket) do
            {:ok, data} -> Process.send(parent, {:zmq, :ok, data}, [])
            {:error, reason} -> Process.send(parent, {:zmq, :error, reason}, [])
          end
        end)
      end

      ## DEFAULT IMPLEMENTATIONS
      @impl true

      @spec handle_raw_packet(packet :: Wire.raw_packet(), channel :: pid()) ::
              Wire.raw_packet() | nil
      def handle_raw_packet(packet, channel) do
        case Packet.parse(packet) do
          {:ok, packet} ->
            case handle_packet(packet, channel) do
              nil ->
                nil

              {nil, after_callback} ->
                {nil, after_callback}

              {packet, after_callback} ->
                {Packet.encode(packet), after_callback}

              packet ->
                Packet.encode(packet)
            end

          {:error, reason} ->
            Logger.warn("Failed to parse packet: #{inspect(packet)}")
            nil
        end
      end

      @impl true
      @spec handle_packet(packet :: Packet.t(), channel :: Wire.channel()) :: Packet.t() | nil
      def handle_packet(packet, channel), do: nil

      defoverridable handle_raw_packet: 2, handle_packet: 2
    end
  end
end
