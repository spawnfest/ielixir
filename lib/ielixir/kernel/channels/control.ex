defmodule IElixir.Kernel.Channels.Control do
  @moduledoc """
  "Shell: this single ROUTER socket allows multiple incoming connections from
  frontends, and this is the socket where requests for code execution, object
  information, prompts, etc. are made to the kernel by any frontend.
  The communication on this socket is a sequence of request/reply actions from
  each frontend and the kernel."
  From https://ipython.org/ipython-doc/dev/development/messaging.html
  """

  use IElixir.Kernel.Socket.Router, name: "control"

  alias IElixir.Kernel.Wire
  alias IElixir.Kernel.Wire.Packet
  alias IElixir.Kernel.Wire.Message
  alias IElixir.Kernel.Session

  @impl true
  @spec handle_packet(packet :: Packet.t(), channel :: Wire.channel()) ::
          Packet.t() | nil | {Packet.t() | nil, (() -> :ok)}

  def handle_packet(
        %Packet{
          uuids: uuids,
          message:
            %Message{header: %{msg_type: "shutdown_request"}, content: %{"restart" => restart}} =
              parent_message
        } = _packet,
        _channel
      ) do
    Logger.debug("Received shutdown_request")

    {
      %Packet{
        uuids: uuids,
        message:
          Message.from_parent(
            Session.get_session(),
            parent_message,
            "shutdown_reply",
            content: %{
              status: "ok",
              restart: restart
            }
          )
      },
      &System.halt/0
    }
  end
end
