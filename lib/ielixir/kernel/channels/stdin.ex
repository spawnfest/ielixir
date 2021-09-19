defmodule IElixir.Kernel.Channels.StdIn do
  use IElixir.Kernel.Socket.Router, name: "stdin"

  # This function is a stub - it is not working
  def handle_packet(message_multipart, _channel) do
    Logger.info("StdIn message received #{inspect(message_multipart)}")
    {message_multipart, fn -> nil end}
  end
end
