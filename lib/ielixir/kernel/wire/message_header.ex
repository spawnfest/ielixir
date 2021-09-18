defmodule IElixir.Kernel.Wire.MessageHeader do
  @moduledoc """
  NOTE: Session field differs for kernel and client messages.
  So CLIENT session identifies different clients,
  while KERNEL session identifies different KERNEL sessions.
  """

  @doc """
  Composes a new header.
  Message id is generated randomly, and the time is taken from the current time of this function call.
  """
  def new(session_uuid, message_type) do
    %{
      # Generating new random uuid
      msg_id: :uuid.uuid_to_string(:uuid.get_v4(), :binary_standard),
      # Username is general for the kernel
      username: "ielixir_kernel",
      session: session_uuid,
      msg_type: message_type,
      date: NaiveDateTime.to_iso8601(NaiveDateTime.utc_now()),
      version: "5.3"
    }
  end
end
