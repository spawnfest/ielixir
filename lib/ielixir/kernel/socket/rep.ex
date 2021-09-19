defmodule IElixir.Kernel.Socket.Rep do
  @moduledoc false

  alias IElixir.Kernel.Wire
  alias IElixir.Kernel.Wire.Packet

  @callback handle_packet(packet :: Packet.t(), channel :: Wire.channel()) :: Packet.t()
  @callback handle_raw_packet(packet :: Wire.raw_packet(), channel :: Wire.channel()) ::
              Wire.raw_packet()

  defmacro __using__(opts) do
    channel_name = Keyword.get(opts, :name)

    quote location: :keep do
      require Logger
      use GenServer
      @behaviour unquote(__MODULE__)

      def start_link(%IElixir.Kernel.Socket.Config{} = channel_config) do
        GenServer.start_link(__MODULE__, channel_config, name: __MODULE__)
      end

      # API
      def init(%IElixir.Kernel.Socket.Config{connection_data: connection_data}) do
        Logger.debug("Starting channel #{unquote(channel_name)} with PID: #{inspect(self())}")

        {
          :ok,
          %{
            channel:
              IElixir.Kernel.Wire.make_channel(
                connection_data,
                unquote(channel_name),
                :rep
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
        reply = handle_raw_packet(packet, channel)
        :chumak.send(channel, reply)
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
          # This call is blocking
          case :chumak.recv(socket) do
            {:ok, data} -> Process.send(parent, {:zmq, :ok, data}, [])
            {:error, reason} -> Process.send(parent, {:zmq, :error, reason}, [])
          end
        end)
      end

      ## DEFAULT IMPLEMENTATIONS
      def handle_raw_packet(packet, channel) do
        case Packet.parse(packet) do
          {:ok, packet} ->
            handle_packet(packet, channel)
            |> Packet.encode()

          {:error, reason} ->
            Logger.warn("Failed to parse packet: #{inspect(packet)}")
            packet
        end
      end

      # Sending packet back. Should be overridden by user in most cases.
      def handle_packet(packet, channel), do: packet

      defoverridable handle_raw_packet: 2, handle_packet: 2
    end
  end
end
