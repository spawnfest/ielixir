defmodule IElixir.Kernel.Wire.Message do
  @moduledoc """
  This is documentation for Message structure and some utils that helps in
  encoding, parsing, assembling and sending messages.

  Here are extracted functions which helps with messages management.
  """

  alias IElixir.Kernel.Wire.MessageHeader

  require Logger

  defstruct header: %{},
            parent_header: %{},
            metadata: %{},
            content: %{},
            buffers: []

  @type t() :: %__MODULE__{}

  @doc """
  Function will make a new message.

  Params:

  * session_uuid - UUID that defines current kernel process
  * parent_message - parent message should be passed. Then, the message will be baked as a RESPONSE message for that parent
  * message_type - string that represents the type of the message
  * fields - keyword, that specifies optional params for the message:
    * :metadata
    * :content
    * :buffers
  """
  @spec from_parent(
          session_uuid :: String.t(),
          parent_message :: __MODULE__.t(),
          message_type :: String.t(),
          fields :: Keyword.t()
        ) ::
          __MODULE__.t()
  def from_parent(session_uuid, parent_message, message_type, fields) do
    %__MODULE__{
      # uuids: Keyword.get(fields, :parent, %{uuids: []}).uuids,
      header: MessageHeader.new(session_uuid, message_type),
      parent_header: parent_message.header,
      metadata: Keyword.get(fields, :metadata, %{}),
      content: Keyword.get(fields, :content, %{}),
      buffers: Keyword.get(fields, :buffers, [])
    }
  end

  def from_wire_parts(header_raw, parent_header_raw, metadata_raw, content_raw, buffers_raw) do
    %__MODULE__{
      # uuids: Keyword.get(fields, :parent, %{uuids: []}).uuids,
      header: Jason.decode!(header_raw, keys: :atoms),
      parent_header: Jason.decode!(parent_header_raw, keys: :atoms),
      metadata: Jason.decode!(metadata_raw),
      content: Jason.decode!(content_raw),
      # TODO: Check if it should be parsed. It seems to be a list of binaries
      buffers: buffers_raw
    }
  end
end
