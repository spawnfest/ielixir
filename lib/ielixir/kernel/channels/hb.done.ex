defmodule IElixir.Kernel.Channels.Hb do
  alias IElixir.Kernel.Wire

  @moduledoc """
  Represents HeartBeat channel
  """
  use IElixir.Kernel.Socket.Rep, name: "hb"

  @impl true
  @spec handle_raw_packet(packet :: Wire.raw_packet(), socket :: Wire.channel()) ::
          Wire.raw_packet()
  def handle_raw_packet(packet, _socket) do
    # Basic idea here - message is sent as-is, so no need to parse it.
    Logger.debug("Got heartbeat packet: #{packet}")
    packet
  end
end
