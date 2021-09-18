defmodule IElixir.Kernel.Wire do
  @type raw_packet :: binary() | list(binary())
  @type channel :: pid()

  require Logger

  @doc false
  @spec make_channel(
          connection_data :: any(),
          channel_name :: String.t(),
          channel_type :: :chumak.socket_type()
        ) :: channel()
  def make_channel(connection_data, channel_name, channel_type) do
    sock =
      case :chumak.socket(channel_type, :erlang.binary_to_list(channel_name)) do
        {:ok, socket} -> socket
        {:error, {:already_started, socket}} -> socket
      end

    {transport, host, port} =
      channel_params =
      IElixir.Kernel.ConnectionFile.channel_connection_config(connection_data, channel_name)

    :chumak.bind(sock, transport, host, port)

    Logger.debug("Initializing #{channel_name} agent with params: #{inspect(channel_params)}")

    sock
  end
end
