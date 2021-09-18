defmodule IElixir.Kernel.Channels.IOPub do
  use IElixir.Kernel.Socket.Pub, name: "iopub"

  alias IElixir.Kernel.Wire.Packet
  alias IElixir.Kernel.Wire.Message
  alias IElixir.Kernel.Session

  # Streams
  # https://jupyter-client.readthedocs.io/en/stable/messaging.html#streams-stdout-stderr-etc
  @spec stream(parent_packet :: IElixir.Kernel.Wire.Packet.t(), stream_name :: String.t(), stream_text :: String.t()) :: :ok
  def stream(
        %Packet{message: parent_message, uuids: uuids} = _parent_packet,
        stream_name,
        stream_text
      ) do
    %Packet{
      uuids: uuids,
      message:
        Message.from_parent(
          Session.get_session(),
          parent_message,
          "stream",
          content: %{
            name: stream_name,
            text: stream_text
          }
        )
    }
    |> publish()
  end

  # Display data
  # https://jupyter-client.readthedocs.io/en/stable/messaging.html#display-data
  @spec display_data(parent_packet :: IElixir.Kernel.Wire.Packet.t(), content_fields :: Keyword.t()) :: :ok
  def display_data(
        %Packet{message: parent_message, uuids: uuids} = _parent_packet,
        content_fields # Keyword(data, metadata, transient)
      ) do
    %Packet{
      uuids: uuids,
      message:
        Message.from_parent(
          Session.get_session(),
          parent_message,
          "display_data",
          content: %{
            data: Keyword.get(content_fields, :data, %{}),
            metadata: Keyword.get(content_fields, :metadata, %{}),
            transient: Keyword.get(content_fields, :transient, %{}),
          }
        )
    }
    |> publish()
  end

  # Kernel status
  # https://jupyter-client.readthedocs.io/en/stable/messaging.html#kernel-status

  @spec send_status(parent_packet :: Packet.t(), execution_state :: String.t()) :: :ok
  def send_status(%Packet{message: parent_message, uuids: uuids}, execution_state) do
    %Packet{
      uuids: uuids,
      message:
        Message.from_parent(
          Session.get_session(),
          parent_message,
          "status",
          content: %{execution_state: execution_state}
        )
    }
    |> publish()
  end

  @spec idle_notifier(parent_packet :: Packet.t()) :: (() -> :ok)
  def idle_notifier(parent_packet) do
    fn ->
      send_status(parent_packet, "idle")
    end
  end

  @spec busy_notifier(parent_packet :: Packet.t()) :: (() -> :ok)
  def busy_notifier(parent_packet) do
    fn ->
      send_status(parent_packet, "busy")
    end
  end

  # Clear output
  # https://jupyter-client.readthedocs.io/en/stable/messaging.html#clear-output
  def clear_output(_parent_packet) do
    raise "unimplemented"
  end
end
