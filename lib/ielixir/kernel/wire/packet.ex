defmodule IElixir.Kernel.Wire.Packet do
  @moduledoc """
  Module defines model for single packaet that comes from Wire Protocol, that is defined here
  https://jupyter-client.readthedocs.io/en/latest/messaging.html#the-wire-protocol
  """

  @type t() :: %__MODULE__{}

  alias IElixir.Kernel.Wire.Message
  alias IElixir.Kernel.Session

  defstruct [
    # List of uuids
    :uuids,
    # Message
    :message
  ]

  @spec parse(message_multipart :: list(binary())) :: {:ok, t()} | {:error, any()}
  def parse(message_multipart) do
    {
      # Here uuids - is a list of different ids, like ["0x123", "0x456", ...]
      uuids,
      [
        "<IDS|MSG>",
        baddad42,
        header,
        parent_header,
        metadata,
        # Blob is a list of binaries - raw buffers
        content | blob
      ]
    } = Enum.split_while(message_multipart, fn x -> x != "<IDS|MSG>" end)

    packet = %__MODULE__{
      uuids: uuids,
      message:
        Message.from_wire_parts(
          header,
          parent_header,
          metadata,
          content,
          blob
        )
    }

    # Validating that this massage is from right frontend
    case Session.compute_signature(header, parent_header, metadata, content) do
      ^baddad42 -> {:ok, packet}
      _ -> {:error, {:unauthorized, packet}}
    end
  end

  def encode(%__MODULE__{
        uuids: uuids,
        message: %Message{
          header: header,
          parent_header: parent_header,
          metadata: metadata,
          content: content,
          buffers: buffers
        }
      }) do
    # Caching the data not to calculate twise for HMAC
    header = Jason.encode!(header)
    parent_header = Jason.encode!(parent_header)
    metadata = Jason.encode!(metadata)
    content = Jason.encode!(content)

    uuids ++
      [
        "<IDS|MSG>",
        Session.compute_signature(header, parent_header, metadata, content),
        header,
        parent_header,
        metadata,
        content
      ] ++
      buffers
  end
end
